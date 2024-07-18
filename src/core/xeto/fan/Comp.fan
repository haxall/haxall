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

  ** Call a method slot. If slot is not found then silently ignore and
  ** return null. If slot is defined but not a CompFunc then raise exception.
  Obj? call(Str name, Obj? arg := null) { spi.call(name, arg)  }

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

  ** Set a method slot with a Fantom function.  The Fantom
  ** function must have the signature:
  **   |Comp, ArgType -> RetType|
  This setFunc(Str name, |This, Obj?->Obj?| f)
  {
    set(name, FantomFuncCompFunc(f))
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Callbacks
//////////////////////////////////////////////////////////////////////////

  ** Callback when a slot is modified.  The newVal is null if the slot
  ** was removed.
  Void onChange(Str name, |This self, Obj? newVal| cb) { spi.onChange(name, cb) }

  ** Callback when a method is called
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

  ** How often should this component have its onTimer callback invoked.
  ** Return null if this component has no time based computation.
  virtual Duration? onTimerFreq() { null }

  ** Callback for time based computation based on `onTimerFreq`.
  virtual Void onTimer(DateTime now) {}

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
    this.spiRef = CompSpiFactory.cur.initSpi(this, null)
  }

  ** Constructor for generic component with given spec
  static new makeForSpec(Spec spec) { doMakeForSpec(spec) }
  private new doMakeForSpec(Spec spec)
  {
    this.spiRef = CompSpiFactory.cur.initSpi(this, spec)
  }

  ** Service provider interface
  @NoDoc override CompSpi spi() { spiRef }
  private CompSpi? spiRef
}

**************************************************************************
** CompSpiFactory
**************************************************************************

@Js @NoDoc
mixin CompSpiFactory
{
  ** Actor key for local CompSpace
  static const Str actorKey := "xcsf"

  ** Get the current factory as actor local
  internal static CompSpiFactory cur()
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
  abstract Obj? get(Str name)
  abstract Bool has(Str name)
  abstract Bool missing(Str name)
  abstract Void each(|Obj val, Str name| f)
  abstract Obj? eachWhile(|Obj val, Str name->Obj?| f)
  abstract Obj? call(Str name, Obj? arg)
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

