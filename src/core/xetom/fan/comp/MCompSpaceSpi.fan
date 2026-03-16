//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2024  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack

**
** CompSpaceSpi implementation
**
@Js
class MCompSpaceSpi : CompSpaceSpi
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(CompSpace cs, Namespace ns)
  {
    this.cs = cs
    this.nsRef = ns
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Parent CompSpace instance
  CompSpace cs { private set }

  ** Xeto namespace for this space
  override Namespace ns() { nsRef }
  private Namespace nsRef

  ** Current version of component changes
  override Int ver() { curVer }

  ** Root component
  override Comp root() { rootRef ?: throw Err("Must call load") }

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** Load root component
  override Void load(Comp root)
  {
    if (rootRef != null) unmount(rootRef)
    this.rootRef = root
    mount(root)
  }

  ** Load tree from xeto instances
  override Void loadXeto(Str xeto)
  {
    load(CompFactory(this).load(CompUtil.parse(ns, xeto), null))
  }

  ** Save tree to xeto instances
  override Str saveXeto()
  {
    CompUtil.compSaveToXeto(ns, root)
  }

  ** Has this space been started, but not stopped yet
  override Bool isRunning() { isRunningRef }

  ** Start space.
  override Void start()
  {
    if (Actor.locals[CompSpace.actorKey] !== cs) throw Err("CompSpace not installed in actor local")
    isRunningRef = true
    timersNeedUpdate = true
    cs.onStart
  }

  ** Stop space.
  override Void stop()
  {
    isRunningRef = false
    cs.onStop
  }

//////////////////////////////////////////////////////////////////////////
// Comp Management
//////////////////////////////////////////////////////////////////////////

  ** Initialize server provider interface for given instance
  override CompSpi initCompSpi(CompObj comp)
  {
    CompFactory(this).init(comp)
  }

  ** Create new component instance from spec.
  override Comp create(Spec spec)
  {
    CompFactory(this).create(spec)
  }

  ** Read by id
  override Comp? readById(Ref id, Bool checked := true)
  {
    c := map.get(id)
    if (c != null) return c
    if (checked) throw UnknownRecErr(id.toStr)
    return null
  }

  ** Iterate every component in space
  override Void each(|Comp| f)
  {
    map.each(f)
  }

  ** Iterate every component in space until callback returns non-null
  override Obj? eachWhile(|Comp->Obj?| f)
  {
    map.eachWhile(f)
  }

  ** Hook when component is modified
  internal Void change(MCompSpi spi, CompChangeEvent event)
  {
    // increment version
    updateVer(spi)

    // handle links change
    if (event.name == "links") map.topologyChanged

    // invoke callback on space
    try
      cs.onChange(event)
    catch (Err e)
      err("CompSpace.onChange", e)
  }

  ** Recursively mount component into this space
  internal Void mount(Comp c)
  {
    // increment version
    updateVer(c.spi)

    // add to my lookup tables
    map.add(c)

    // invoke callback on space
    try
      cs.onMount(c)
    catch (Err e)
      err("CompSpace.onMount", e)

    // invoke callback on component
    try
      c.onMount()
    catch (Err e)
      err("${c.typeof}.onMount", e)

    // recurse children
    c.eachChild |kid| { mount(kid) }

    // set flag to indicate we need to update timers
    timersNeedUpdate = true
  }

  ** Recursively unmount component into this space.
  ** 'target' is the original (root) component that was unmounted.
  internal Void unmount(Comp c, Comp target := c)
  {
    // increment version
    updateVer(c.spi)

    // recurse children
    c.eachChild |kid| { unmount(kid, target) }

    // invoke callback on component
    try
      c.onUnmount()
    catch (Err e)
      err("${c.typeof}.onUnmount", e)

    // invoke callback on space
    try
      cs.onUnmount(c)
    catch (Err e)
      err("CompSpace.onUnmount", e)

    // invoke callback on actor state
    if (actorState != null) actorState.onUnmount(c)

    // remove from my lookup tables
    map.remove(c)

    // sanitize the component space, but only once after all kids unmounted
    if (c === target) sanitize

    // set flag to indicate we need to update timers
    timersNeedUpdate = true
  }

  ** Cleanup unresolved links, and reset any unlinked slots back
  ** to their default value.
  internal Void sanitize()
  {
    each |comp|
    {
      if (!comp.has("links")) return

      oldLinks := comp.links
      newLinks := oldLinks
      oldLinks.eachLink |toSlot, link|
      {
        if (newLinks.isEmpty) return

        fromComp := readById(link.fromRef, false)
        if (fromComp != null) return

        newLinks = newLinks.remove(toSlot, link)

        if (!newLinks.isLinked(toSlot))
          comp.set(toSlot, slotDefVal(comp, toSlot))
      }

      if (oldLinks !== newLinks) comp.set("links", newLinks)
    }
  }

  ** Increment space version and assign to comp
  private Void updateVer(MCompSpi spi)
  {
    ++this.curVer
    spi.ver = this.curVer
  }

//////////////////////////////////////////////////////////////////////////
// Namespace
//////////////////////////////////////////////////////////////////////////

  ** Modify the namespace on the fly.  Every component in the current tree
  ** must map to a spec in the new namespace or exception is raised.  This
  ** update does not check that components validate against the new specs.
  override Void updateNamespace(Namespace ns)
  {
    // first check that we have spec for each component
    updateCompSpec(root, ns, false)

    // now commit new specs to component tree
    updateCompSpec(root, ns, true)

    // now update my own namespace ref
    nsRef = ns
  }

  ** Recursively walk the component tree to update specs
  private Void updateCompSpec(Comp c, Namespace ns, Bool commit)
  {
    newSpec := ns.spec(c.spec.qname)
    if (commit) ((MCompSpi)c.spi).specRef = newSpec
    c.eachChild |kid| { updateCompSpec(kid, ns, commit) }
  }

  ** Get the default value a component's slot
  private Obj? slotDefVal(Comp c, Str slotName)
  {
    slotSpec := c.spec.slot(slotName)
    if (slotSpec.meta.has("maybe")) return null
    return ns.instantiate(slotSpec)
  }

//////////////////////////////////////////////////////////////////////////
// Execute
//////////////////////////////////////////////////////////////////////////

  ** This method should be called at periodically to execute components
  ** and check timers.  The frequency this method is called determines
  ** the smallest timer increment.  For example if its called every 100ms
  ** then timers will only fire as fast as 100ms. The current context
  ** must be an CompContext.
  override Void execute()
  {
    if (!isRunningRef) throw Err("CompSpace not running")

    cx := CompContext.curComp

    // if the component tree has been modified, we need to rebuild
    if (timersNeedUpdate)
    {
      timersNeedUpdate = false
      rebuildTimers
    }

    // walk thru timed components to set needExecute flag
    timed.each |spi| { spi.checkTimer(cx.now) }

    // now walk thru every component in topological order
    map.topology.each |comp| { ((MCompSpi)comp.spi).doExecute(cx) }
  }

  ** Walk component tree to build our timers list
  private Void rebuildTimers()
  {
    acc := MCompSpi[,]
    acc.capacity = this.timed.size
    doRebuildTimers(acc, rootRef)
    this.timed = acc.isEmpty ? MCompSpi#.emptyList : acc
  }

  ** Walk component tree to build our timers list
  private static Void doRebuildTimers(MCompSpi[] acc, Comp c)
  {
    freq := c.onExecuteFreq
    if (freq != null) acc.add(c.spi)
    c.eachChild |kid| { doRebuildTimers(acc, kid) }
  }

  ** Debug dump the topology
  override Void dumpTopology(OutStream out := Env.cur.out) { map.dumpTopology(out) }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Get the edit api for this CompSpace
  once CompSpaceEdit edit() { CompSpaceEdit(cs) }

  ** Generate new id
  internal Ref genId() { map.genId }

  ** Log error
  Void err(Str msg, Err? err := null)
  {
    Console.cur.err(msg)
    if (err != null) Console.cur.err(err.traceToStr)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  internal CompSpaceActorState? actorState
  private Bool isRunningRef
  private Comp? rootRef
  private CompMap map := CompMap()
  private Bool timersNeedUpdate
  private MCompSpi[] timed := MCompSpi#.emptyList
  private Int curVer
}

