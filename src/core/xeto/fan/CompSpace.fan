//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 May 2024  Brian Frank  Sandbridge
//

using concurrent
using util

**
** CompSpace manages a tree of components and their execution
** environment - see [documentation]`hx.doc.haxall::Comps`.
**
@Js
class CompSpace
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Actors local key for CompSpace.  This actor local must
  ** be set before any Comp can be constructed against the namespace.
  @NoDoc static const Str actorKey := "xeto::cs"

  ** Constructor - must call `install` before creating any components.
  new make(Namespace ns)
  {
    this.spi = Type.find("xetom::MCompSpaceSpi").make([this, ns])
  }

  ** Install this space as the actor local.
  This install()
  {
    if (Actor.locals[actorKey] != null) throw Err("CompSpace already installed for current thread")
    Actor.locals[actorKey] = this
    load(CompObj()) // now safe to install default root
    return this
  }

  ** Stop and uninstall the actor local if defined.
  static Void uninstall()
  {
    cs := Actor.locals.remove(actorKey) as CompSpace
    if (cs != null) cs.stop
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Service provider interface for xetom implementation code
  @NoDoc CompSpaceSpi spi { private set }

  ** Xeto namespace for the space
  Namespace ns() { spi.ns }

  ** Root component
  virtual Comp root() { spi.root }

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** Load tree with root component
  This load(Comp root) { spi.load(root); return this }

  ** Load tree from xeto instance tree
  @NoDoc This loadXeto(Str xeto) { spi.loadXeto(xeto); return this }

  ** Save tree to xeto isntance tree
  @NoDoc Str saveXeto() { spi.saveXeto }

  ** Has this space been started, but not stopped yet
  Bool isRunning() { spi.isRunning}

  ** Start space to initialize and begin `execute` calls
  This start() { spi.start; return this }

  ** Stop space to cleanup and cease `execute` calls
  This stop() { spi.stop; return this }

  ** This method should be called at periodically to execute components
  ** and check timers.  The frequency this method is called determines
  ** the smallest timer increment.  For example if its called every 100ms
  ** then timers will only fire as fast as 100ms. The current context
  ** must be an instance of `CompContext`.
  Void execute() { spi.execute }

//////////////////////////////////////////////////////////////////////////
// Comp Tree
//////////////////////////////////////////////////////////////////////////

  ** Create new component instance for spec
  Comp create(Spec spec)  { spi.create(spec) }

  ** Create new component instance tree from dicts
  @NoDoc Comp createFromDict(Dict dict)  { spi.createFromDict(dict) }

  ** Read a component by its id in this space
  Comp? readById(Ref id, Bool checked := true) { spi.readById(id, checked) }

  ** Iterate every component in space
  Void each(|Comp| f) { spi.each(f) }

  ** Iterate every component in space until callback returns non-null
  Obj? eachWhile(|Comp->Obj?| f) { spi.eachWhile(f) }

//////////////////////////////////////////////////////////////////////////
// Callbacks
//////////////////////////////////////////////////////////////////////////

  ** Callback for subclasses on start
  @NoDoc virtual Void onStart() {}

  ** Callback for subclasses on stop
  @NoDoc virtual Void onStop() {}

  ** Callback when component is mounted into tree
  @NoDoc virtual Void onMount(Comp c) {}

  ** Callback when component is unmounted from tree
  @NoDoc virtual Void onUnmount(Comp c) {}

  ** Callback anytime a component in the space is modified.
  ** The name and value are the slot modified, or null for a remove.
  @NoDoc virtual Void onChange(CompChangeEvent event) {}

  ** Callback anytime a component method is called
  @NoDoc virtual Void onCall(CompCallEvent event) {}

}

**************************************************************************
** CompContext
**************************************************************************

**
** Context for `CompSpace.execute`
**
@Js
mixin CompContext : ActorContext
{
  ** Current context for actor thread
  ** NOTE: this will be replaced by just ActorContext.cur in 4.0
  @NoDoc static CompContext? curComp(Bool checked := true) { curx(checked) }

  ** Current DateTime to use; might be simulated
  abstract DateTime now()
}

**************************************************************************
** CompSpaceSpi
**************************************************************************

@Js @NoDoc
abstract class CompSpaceSpi
{
  abstract Namespace ns()
  abstract CompSpi initCompSpi(CompObj c)
  abstract Comp root()
  abstract Int ver()
  abstract Void load(Comp root)
  abstract Void loadXeto(Str xeto)
  abstract Str saveXeto()
  abstract Bool isRunning()
  abstract Void start()
  abstract Void stop()
  abstract Comp create(Spec spec)
  abstract Comp createFromDict(Dict dict)
  abstract Comp? readById(Ref id, Bool checked := true)
  abstract Void each(|Comp| f)
  abstract Obj? eachWhile(|Comp->Obj?| f)
  abstract Void updateNamespace(Namespace ns)
  abstract Void execute()
  abstract Void dumpTopology(OutStream out := Env.cur.out)
}

