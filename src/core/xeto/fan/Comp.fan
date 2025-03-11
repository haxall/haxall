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
** Component or function block
**
@Js
mixin Comp
{

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Return id that uniquely identifies this component within its space.
  Ref id() { spi.id }

  ** Return display string for this component
  Str dis() { spi.dis }

  ** Xeto type for this component
  Spec spec() { spi.spec }

  ** Return debug string
  override Str toStr() { spi.toStr }

  ** Service provider interface
  @NoDoc abstract CompSpi spi()

//////////////////////////////////////////////////////////////////////////
// Slots
//////////////////////////////////////////////////////////////////////////

  ** Get the given slot value or null if slot name not defined.
  @Operator Obj? get(Str name) { spi.get(name) }

  ** Return true if this component has a slot by given name.
  Bool has(Str name) { spi.has(name) }

  ** Return true if the component does not have a slot by given name.
  Bool missing(Str name) { spi.missing(name) }

  ** Iterate slot name/value pairs using same semantics as `get`.
  Void each(|Obj val, Str name| f) { spi.each(f) }

  ** Iterate name/value pairs until callback returns non-null
  Obj? eachWhile(|Obj val, Str name->Obj?| f) { spi.eachWhile(f) }

  ** Get or set the slot mapped by the given name.
  override final Obj? trap(Str name, Obj?[]? args := null)
  {
    if (args == null || args.isEmpty)
    {
      val := spi.get(name)
      if (val != null) return val
      throw UnknownSlotErr(name)
    }
    if (args.size == 1) return set(name, args[0])
    throw ArgErr("Unsupported args to trap")
  }

  ** Call a method slot synchronously. If slot is not found then silently
  ** ignore and return null. If slot is defined but not a Function or the
  ** Function must be called asynchronously then raise exception.
  Obj? call(Str name, Obj? arg := null) { spi.call(name, arg)  }

  ** Call a method slot asynchronously. If slot is not found then
  ** silently ignore and return null. If slot is defined but not an
  ** Function then raise exception.
  Void callAsync(Str name, Obj? arg, |Err?, Obj?| cb) { spi.callAsync(name, arg, cb)  }

//////////////////////////////////////////////////////////////////////////
// Updates
//////////////////////////////////////////////////////////////////////////

  ** Set a slot by name.  If val is null, then this is a
  ** convenience for remove.
  @Operator This set(Str name, Obj? val)
  {
    spi.set(name, val)
    return this
  }

  ** Add a slot.  If name is null one is auto-generated
  ** otherwise the name must be unique.
  @Operator This add(Obj val, Str? name := null)
  {
    spi.add(val, name)
    return this
  }

  ** Remove a slot by name.  Do nothing is name isn't mapped.
  This remove(Str name)
  {
    spi.remove(name)
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Callbacks
//////////////////////////////////////////////////////////////////////////

  ** Callback when a slot is modified.  The newVal is null if the slot
  ** was removed.
  Void onChange(Str name, |This self, Obj? newVal| cb) { spi.onChange(name, cb) }

  ** Callback when a method is called. This is an observer callback
  ** only and will not determine the result value of calling a method.
  Void onCall(Str name, |This self, Obj? arg| cb) { spi.onCall(name, cb) }

  ** Remove an onChange callback
  Void onChangeRemove(Str name, Func cb) { spi.onChangeRemove(name, cb) }

  ** Remove an onCall callback
  Void onCallRemove(Str name, Func cb) { spi.onCallRemove(name, cb) }

  ** Special onChange callback to handle built-in logic, called before onChange.
  @NoDoc virtual Void onChangePre(Str name, Obj? newVal) {}

  ** Callback on instance itself when a slot is modified. Value is null
  ** if slot removed.
  virtual Void onChangeThis(Str name, Obj? newVal) {}

  ** Callback on instance itself when a call is invoked.
  virtual Void onCallThis(Str name, Obj? arg) {}

  ** Callback whem mounted into a component space
  @NoDoc virtual Void onMount() {}

  ** Callback whem mounted into a component space
  @NoDoc virtual Void onUnmount() {}

  ** Callback to recompute component state.
  ** This is always called within a CompContext.
  virtual Void onExecute() {}

  ** How often should this component have its onExecute callback invoked.
  ** Return null if this component has no time based computation.
  virtual Duration? onExecuteFreq() { null }

//////////////////////////////////////////////////////////////////////////
// Tree
//////////////////////////////////////////////////////////////////////////

  ** Return if this component is mounted into a component space
  Bool isMounted() { spi.isMounted }

  ** Parent component or null if root/unmounted
  virtual Comp? parent() { spi.parent }

  ** Slot name under parent or "" if parent is null
  Str name() { spi.name }

  ** Is this is an ancestor in the tree of the given component.
  ** If the given component is this, then return true.
  Bool isAbove(Comp child) { spi.isAbove(child) }

  ** Is this component is a descendant in the tree of the given component.
  ** If the given component is this, then return true.
  Bool isBelow(Comp parent) { parent.isAbove(this) }

  ** Check if a child component is mapped by the given name
  Bool hasChild(Str name) { spi.hasChild(name) }

  ** Lookup a child component by name
  virtual Comp? child(Str name, Bool checked := true) { spi.child(name, checked) }

  ** Iterate children components in the tree structure
  Void eachChild(|Comp,Str| f) { spi.eachChild(f) }

  ** Gets links slot as dict of incoming component links
  Links links() { spi.links }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Debug dump the component tree to the console
  @NoDoc virtual Void dump(Console con := Console.cur, Obj? opts := null) { spi.dump(con, opts) }

}

**************************************************************************
** CompObj
**************************************************************************

**
** CompObj is the base class for all Comp subclasses
**
@Js
class CompObj : Comp
{
  ** Constructor for subclasses
  new make()
  {
    this.spiRef = AbstractCompSpace.cur.initSpi(this, null)
  }

  ** Constructor for generic component with given spec
  static new makeForSpec(Spec spec) { doMakeForSpec(spec) }
  private new doMakeForSpec(Spec spec)
  {
    this.spiRef = AbstractCompSpace.cur.initSpi(this, spec)
  }

  ** Service provider interface
  @NoDoc override CompSpi spi() { spiRef }
  private CompSpi? spiRef
}

**************************************************************************
** CompContext
**************************************************************************

**
** Context for Comp.onExecute
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
** AbstractCompSpace
**************************************************************************

@Js @NoDoc
mixin AbstractCompSpace
{
  ** Actor key for local CompSpace
  static const Str actorKey := "xeto::cs"

  ** Get the current space as actor local
  internal static AbstractCompSpace cur()
  {
    Actor.locals[actorKey] ?: throw Err("No CompSpace active for current thread")
  }

  ** Initialize a new service provider interface for given component
  abstract CompSpi initSpi(CompObj c, Spec? spec)
}

**************************************************************************
** CompSpi
**************************************************************************

@Js @NoDoc
mixin CompSpi
{
  abstract Ref id()
  abstract Str dis()
  abstract Spec spec()
  abstract Int ver()
  abstract Obj? get(Str name)
  abstract Bool has(Str name)
  abstract Bool missing(Str name)
  abstract Void each(|Obj val, Str name| f)
  abstract Obj? eachWhile(|Obj val, Str name->Obj?| f)
  abstract Obj? call(Str name, Obj? arg)
  abstract Void callAsync(Str name, Obj? arg, |Err?, Obj?| cb)
  abstract Links links()
  abstract Void set(Str name, Obj? val)
  abstract Void add(Obj val, Str? name)
  abstract Void remove(Str name)
  abstract Bool isMounted()
  abstract Comp? parent()
  abstract Str name()
  abstract Bool isAbove(Comp child)
  abstract Bool isBelow(Comp parent)
  abstract Bool hasChild(Str name)
  abstract Comp? child(Str name, Bool checked)
  abstract Void eachChild(|Comp,Str| f)
  abstract Void onChange(Str name, |Comp, Obj?| cb)
  abstract Void onCall(Str name, |Comp, Obj?| cb)
  abstract Void onChangeRemove(Str name, Func cb)
  abstract Void onCallRemove(Str name, Func cb)
  abstract Void dump(Console con, Obj? opts)
}

