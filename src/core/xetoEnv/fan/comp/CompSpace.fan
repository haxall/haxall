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
using haystack::Dict
using haystack::Ref

**
** CompSpace manages a tree of components.  It is the base class for
** different component applications for control, Ion UI, and remote
** programming
**
@Js
class CompSpace : AbstractCompSpace
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(LibNamespace ns)
  {
    this.nsRef = ns
  }

  ** Initialize the root - this must be called exactly once during initialization
  This initRoot(|This->Comp| f)
  {
    if (rootRef != null) throw Err("Root already initialized")

    // use callback to make root while this is installed as actor local
    Actor.locals[actorKey] = this
    try
      this.rootRef = f(this)
    finally
    Actor.locals.remove(actorKey)
    mount(root)

    return this
  }

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** Current version of component changes
  Int ver() { curVer }

  ** Has this space been started, but not stopped yet
  Bool isRunning() { isRunningRef }

  ** Start space.  Sublasses must begin to call checkTimers
  Void start()
  {
    isRunningRef = true
    timersNeedUpdate = true
    if (!ns.isAllLoaded) ns.libs // force all libs to load into memory
    onStart
  }

  ** Stop space.  Sublasses must cease to call checkTimers
  Void stop()
  {
    isRunningRef = false
    onStop
  }

  ** Callback for subclasses on start
  virtual Void onStart() {}

  ** Callback for subclasses on stop
  virtual Void onStop() {}

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Xeto namespace for this space
  LibNamespace ns() { nsRef }
  private LibNamespace nsRef

  ** Root component
  virtual Comp root() { rootRef ?: throw Err("Must call initRoot") }

//////////////////////////////////////////////////////////////////////////
// Loading/Saving
//////////////////////////////////////////////////////////////////////////

  ** Check that the xeto can be loaded or raise exception
  This checkLoad(Str xeto)
  {
    parse(xeto)
    return this
  }

  ** Load tree from xeto instances
  This load(Str xeto)
  {
    root := parse(xeto)
    initRoot |self->Comp| { create(root) }
    return this
  }

  ** Save tree to eto instances
  Str save()
  {
    rootDict := CompUtil.compSave(root)
    buf := StrBuf()
    ns.writeData(buf.out, rootDict)
    return buf.toStr
  }

  private Dict parse(Str xeto)
  {
    ns.compileData(xeto) as Dict ?: throw Err("Expecting one dict root")
  }

//////////////////////////////////////////////////////////////////////////
// Comp Management
//////////////////////////////////////////////////////////////////////////

  ** Convenience to create new default component instance from spec.
  Comp createSpec(Spec spec)
  {
    create(Etc.makeDict1("spec", spec._id))
  }

  ** Create new component instance from dict state.
  ** The dict must have a Comp spec tag.
  Comp create(Dict dict)
  {
    CompFactory.create(this, [dict]).first
  }

  ** Create new list of component instances from dict state.
  ** Each dict must have a Comp spec tag.
  Comp[] createAll(Dict[] dicts)
  {
    CompFactory.create(this, dicts)
  }

  ** Create post-proessing
  virtual Void onCreate(Comp comp) {}

  ** Initialize server provider interface for given instance
  override CompSpi initSpi(CompObj c, Spec? spec)
  {
    CompFactory.initSpi(this, c, spec)
  }

  ** Read by id
  Comp? readById(Ref id, Bool checked := true)
  {
    c := byId.get(id)
    if (c != null) return c
    if (checked) throw UnknownRecErr(id.toStr)
    return null
  }

  ** Iterate every component in space
  Void each(|Comp| f)
  {
    byId.each(f)
  }

  ** Hook when component is modified
  internal Void change(MCompSpi spi, Str name, Obj? val)
  {
    // increment version
    updateVer(spi)

    // invoke callback on space
    try
      onChange(spi.comp, name, val)
    catch (Err e)
      err("CompSpace.onChange", e)
  }

  ** Recursively mount component into this space
  internal Void mount(Comp c)
  {
    // increment version
    updateVer(c.spi)

    // add to my lookup tables
    byId.add(c.id, c)

    // invoke callback on space
    try
      onMount(c)
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

  ** Recursively unmount component into this space
  internal Void unmount(Comp c)
  {
    // increment version
    updateVer(c.spi)

    // recurse children
    c.eachChild |kid| { unmount(kid) }

    // invoke callback on component
    try
      c.onUnmount()
    catch (Err e)
      err("${c.typeof}.onUnmount", e)

    // invoke callback on space
    try
      onUnmount(c)
    catch (Err e)
      err("CompSpace.onUnmount", e)

    // invoke callback on actor state
    if (actorState != null) actorState.onUnmount(c)

    // remove from my lookup tables
    byId.remove(c.id)

    // set flag to indicate we need to update timers
    timersNeedUpdate = true
  }

  ** Increment space version and assign to comp
  private Void updateVer(MCompSpi spi)
  {
    ++this.curVer
    spi.ver = this.curVer
  }

  ** Callback when component is mounted into tree
  virtual Void onMount(Comp c) {}

  ** Callback when component is unmounted from tree
  virtual Void onUnmount(Comp c) {}

  ** Callback anytime a component in the space is modified.
  ** The name and value are the slot modified, or null for a remove.
  virtual Void onChange(Comp comp, Str name, Obj? val) {}

//////////////////////////////////////////////////////////////////////////
// Namespace
//////////////////////////////////////////////////////////////////////////

  ** Modify the namespace on the fly.  Every component in the current tree
  ** must map to a spec in the new namespace or exception is raised.  This
  ** update does not check that components validate against the new specs.
  Void updateNamespace(LibNamespace ns)
  {
    // first check that we have spec for each component
    updateCompSpec(root, ns, false)

    // now commit new specs to component tree
    updateCompSpec(root, ns, true)

    // now update my own namespace ref
    nsRef = ns
  }

  ** Recursively walk the component tree to update specs
  private Void updateCompSpec(Comp c, LibNamespace ns, Bool commit)
  {
    newSpec := ns.spec(c.spec.qname)
    if (commit) ((MCompSpi)c.spi).specRef = newSpec
    c.eachChild |kid| { updateCompSpec(kid, ns, commit) }
  }

//////////////////////////////////////////////////////////////////////////
// Execute
//////////////////////////////////////////////////////////////////////////

  ** This method should be called at periodically to execute components
  ** and check timers.  The frequency this method is called determines
  ** the smallest timer increment.  For example if its called every 100ms
  ** then timers will only fire as fast as 100ms. The current context
  ** must be an CompContext.
  Void execute()
  {
    cx := CompContext.curComp

    // if the component tree has been modified, we need to rebuild
    if (timersNeedUpdate)
    {
      timersNeedUpdate = false
      rebuildTimers
    }

// TODO
each |comp| { if (comp.onExecuteFreq == null) ((MCompSpi)comp.spi).needsExecute = true }

    // walk thru timed components to set needExecute flag
    timed.each |spi| { spi.checkTimer(cx.now) }

    // now walk thru every component that has been triggered to execute
    each |comp| { ((MCompSpi)comp.spi).checkExecute(cx) }
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

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Generate new id
  internal haystack::Ref genId()
  {
    compCounter++
    return haystack::Ref(""+compCounter)
  }

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
  private Ref:Comp byId := [:]
  private Bool timersNeedUpdate
  private MCompSpi[] timed := MCompSpi#.emptyList
  private Int compCounter := 0
  private Int curVer
}

