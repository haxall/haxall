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
** Component or function block - see [documentation]`hx.doc.haxall::Comps`.
**
@Js
mixin Comp
{

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** CompSpace used to create this component
  CompSpace cs() { spi.cs }

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

  ** Return if this component has a CompFunc by given name
  Bool hasFunc(Str name) { spi.hasFunc(name) }

  ** Lookup func type signature for CompFunc function slot.
  Spec? funcType(Str name, Bool checked := true) { spi.funcType(name, checked) }

  ** Return true if this component has slot with non-null value.
  Bool has(Str name) { spi.has(name) }

  ** Return true if this component does not have slot with non-null value.
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

  ** Add a slot if value is not null. If name is null one is auto-generated.
  This addNotNull(Obj? val, Str? name := null)
  {
    if (val != null) add(val, name)
    return this
  }

  ** Remove a slot by name.  Do nothing is name isn't mapped.
  This remove(Str name)
  {
    spi.remove(name)
    return this
  }

  ** Reorder the slots.  The given list of names must match the existing
  ** slot names.  Slots defined statically by the spec cannot be reordered
  ** and will have indetermine behavior if they are not included in the
  ** their original order (in the future this may raise an exception).
  This reorder(Str[] names)
  {
    spi.reorder(names)
    return this
  }

  ** Call component function slot by name - slot value must be `CompFunc`.
  Obj? call(Str name, Obj? arg)
  {
    spi.call(name, arg)
  }

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** Callback when a slot is modified on this instance.  The slot is
  ** non-null if name maps to a slot on the component's spec.  If the
  ** operation if a remove then newVal is null.
  virtual Void onChange(CompChangeEvent event) {}

  ** Callback when a method is called on this instance.
  virtual Void onCall(CompCallEvent event) {}

  ** Special onChange callback to handle built-in framework logic, called
  ** before onChange.  The default implementation calls execute if the
  ** slot is not transient.
  @NoDoc virtual Void onChangeFw(CompChangeEvent event)
  {
    if (event.slot != null && !event.slot.isTransient) execute
  }

  ** Special callback to handle built-in framework logic when a method is called.
  @NoDoc virtual Void onCallFw(CompCallEvent event) {}

  ** Callback whem mounted into a component space
  @NoDoc virtual Void onMount() {}

  ** Callback whem mounted into a component space
  @NoDoc virtual Void onUnmount() {}

  ** Schedule an callback to onExecute on the next execution cycle
  Void execute() { spi.execute }

  ** Callback to recompute component state.  This is always called
  ** within a CompContext.  If not overriden then the default behavior
  ** attempts to call the 'onExecute' method defined in Xeto.
  virtual Void onExecute() { spi.onExecute }

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
  @NoDoc Bool isAbove(Comp child) { spi.isAbove(child) }

  ** Is this component is a descendant in the tree of the given component.
  ** If the given component is this, then return true.
  @NoDoc Bool isBelow(Comp parent) { parent.isAbove(this) }

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
  @NoDoc virtual Void dump(Console? con := null, Obj? opts := null) { spi.dump(con, opts) }

}

**************************************************************************
** CompObj
**************************************************************************

**
** CompObj is the base class for all Comp subclasses.  All
** constructors must be run within the context for a CompSpace.
** See [documentation]`hx.doc.haxall::Comps`.
**
@Js
class CompObj : Comp
{
  ** Constructor for subclasses
  new make()
  {
    cs := Actor.locals[CompSpace.actorKey] as CompSpace ?: throw Err("No CompSpace active for current thread")
    this.spiRef = cs.spi.initCompSpi(this)
    this.spiRef.init
  }

  ** Service provider interface
  @NoDoc override CompSpi spi() { spiRef }
  private CompSpi? spiRef
}

**************************************************************************
** CompFunc
**************************************************************************

**
** Component method function value.  CompFuncs always take exactly one
** parameter.  They can be declared statically as a slot using meta and
** standard func signature pattern, or dynamically in instance data using
** a dict value.   See [documentation]`doc.xeto::Comps#compfunc`
**
@Js
const mixin CompFunc : Dict {}

**************************************************************************
** CompChangeEvent
**************************************************************************

**
** CompChangeEvent includes details when a component slot is modified
**
@Js
class CompChangeEvent
{
  @NoDoc new make(Comp comp, Str name, Spec? slot, Obj? oldVal, Obj? newVal)
  {
    this.comp   = comp
    this.name   = name
    this.slot   = slot
    this.oldVal = oldVal
    this.newVal = newVal
  }

  ** Subject component
  Comp comp { private set }

  ** Name of slot modified
  const Str name

  ** Spec of slot if defined for name (null if dynamic slot)
  const Spec? slot

  ** Old value or null if adding new slot
  Obj? oldVal { private set }

  ** New value or null if removing slot
  Obj? newVal { private set }

  ** Debug string - format subject to change
  override Str toStr() { "$comp | $name | $oldVal => $newVal" }
}

**************************************************************************
** CompCallEvent
**************************************************************************

**
** CompCallEvent includes details when a component method is called
**
@Js
class CompCallEvent
{
  @NoDoc new make(Comp comp, Str name, CompFunc func, Obj? arg, Obj? ret)
  {
    this.comp = comp
    this.name = name
    this.func = func
    this.arg  = arg
    this.ret  = ret
  }

  ** Subject component
  Comp comp { private set }

  ** Component slot name
  const Str name

  ** Component function called
  const CompFunc func

  ** Argument passed
  Obj? arg { private set }

  ** Return value of the method
  Obj? ret { private set }

  ** Debug string - format subject to change
  override Str toStr() { "$comp | $name | $arg => $ret" }
}

**************************************************************************
** CompSpi
**************************************************************************

@Js @NoDoc
mixin CompSpi
{
  abstract Void init()
  abstract CompSpace cs()
  abstract Ref id()
  abstract Str dis()
  abstract Namespace ns()
  abstract Spec spec()
  abstract Int ver()
  abstract Obj? get(Str name)
  abstract Bool hasFunc(Str name)
  abstract Spec? funcType(Str name, Bool checked := true)
  abstract Bool has(Str name)
  abstract Bool missing(Str name)
  abstract Void each(|Obj val, Str name| f)
  abstract Obj? eachWhile(|Obj val, Str name->Obj?| f)
  abstract Links links()
  abstract Void set(Str name, Obj? val)
  abstract Void add(Obj val, Str? name)
  abstract Void remove(Str name)
  abstract Void reorder(Str[] names)
  abstract Obj? call(Str name, Obj? arg)
  abstract Bool isMounted()
  abstract Comp? parent()
  abstract Str name()
  abstract Bool isAbove(Comp child)
  abstract Bool isBelow(Comp parent)
  abstract Bool hasChild(Str name)
  abstract Comp? child(Str name, Bool checked)
  abstract Void eachChild(|Comp,Str| f)
  abstract Void execute()
  abstract Void onExecute()
  abstract Void dump(Console? con, Obj? opts)
}

