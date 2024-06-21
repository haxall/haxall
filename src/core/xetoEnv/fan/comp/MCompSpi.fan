//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Nov 2023  Brian Frank  Creation
//   21 May 2024  Brian Frank  Port into xetoEnv
//

using util
using xeto
using haystack
using haystack::Dict
using haystack::Ref

**
** CompSpi implementation
**
@Js
class MCompSpi : CompSpi
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(CompSpace cs, CompObj comp, Spec spec, Str:Obj slots)
  {
    this.cs      = cs
    this.comp    = comp
    this.specRef = spec
    this.slots   = slots
    this.id      = slots.getChecked("id")
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  CompSpace cs { private set }

  Comp comp { private set }

  override Spec spec() { specRef }
  internal Spec? specRef

  override const Ref id

  override Str dis() { get("dis") ?: toStr }

  override Str toStr() { "@$id $spec.qname" }

//////////////////////////////////////////////////////////////////////////
// Slots
//////////////////////////////////////////////////////////////////////////

  override Obj? get(Str name)
  {
    slots.get(name)
  }

  override Bool has(Str name)
  {
    get(name) != null
  }

  override Bool missing(Str name)
  {
    get(name) == null
  }

  override Void each(|Obj,Str| f)
  {
    slots.each(f)
  }

  override Obj? eachWhile(|Obj,Str->Obj?| f)
  {
    slots.eachWhile(f)
  }

  override Obj? call(Str name, Obj? arg)
  {
    // check for func slot value
    val := get(name)

    // if slot not defined, then return null
    if (val == null) return null

    // call as CompFunc
    func := val as CompFunc ?: throw Err("Slot $name.toCode is not CompFunc [$val.typeof]")
    return func.call(comp, arg)
  }

//////////////////////////////////////////////////////////////////////////
// Updates
//////////////////////////////////////////////////////////////////////////

  override Void set(Str name, Obj? val)
  {
    if (val == null)
    {
      remove(name)
    }
    else
    {
      checkName(name)
      checkSet(name, val)
      doSet(name, val)
    }
  }

  override Void add(Obj val, Str? name)
  {
    if (name != null)
    {
      if (has(name)) throw DuplicateNameErr(name)
      checkName(name)
    }
    else
    {
      name = autoName
    }
    checkSet(name, val)
    doSet(name, val)
  }

  private Void checkSet(Str name, Obj val)
  {
    if (CompUtil.isReservedSlot(name))
      throw InvalidChangeErr("'$name' may not be modified")

    slot := spec.slot(name, false)
    if (slot == null) return null

    // map value to spec
    valSpec := val is Comp ? ((Comp)val).spec : cs.ns.specOf(val)
    if (!isValidSlotVal(slot, val, valSpec))
      throw InvalidChangeErr("Invalid type for $slot.qname: $slot.type != $valSpec")
  }

  static Bool isValidSlotVal(Spec slot, Obj val, Spec valSpec)
  {
    slotType := slot.type
    if (valSpec.isa(slotType)) return true

    // we use Float for some scalar types like Percent
    return val.typeof === slotType.fantomType
  }

  static Void checkName(Str name)
  {
    if (!Etc.isTagName(name)) throw InvalidNameErr(name)
  }

  private Str autoName()
  {
    for (i := 0; i<10_000; ++i)
    {
      name := "_" + i
      if (missing(name)) return name
    }
    throw Err("Too many names!")
  }

  override Void remove(Str name)
  {
    if (CompUtil.isReservedSlot(name))
      throw InvalidChangeErr("'$name' may not be modified")

    slot := spec.slot(name, false)
    if (slot != null && !slot.isMaybe)
    {
      // allow removing a func if we have fallback method
      if (slot.isFunc)
      {
        method := CompUtil.toHandlerMethod(comp, slot)
        if (method != null)
        {
          doSet(name, FantomMethodCompFunc(method))
          return
        }
      }

      throw InvalidChangeErr("$slot.qname is required")
    }

    doRemove(name)
  }

  private Void doSet(Str name, Obj val)
  {
    if (val is Comp) addChild(name, val)
    else if (val isnot CompFunc) val = val.toImmutable
    slots.set(name, val)
    onChange(name, val)
  }

  private Void doRemove(Str name)
  {
    val := slots.remove(name)
    if (val is Comp) removeChild(val)
    onChange(name, val)
  }

  // choke point for all slot changes
  private Void onChange(Str name, Obj? val)
  {
    // invoke
    try
    {
      // special callback
      comp.onChangePre(name, val)

      // standard callback
      comp.onChange(name, val)

      // space level callback
      if (isMounted) cs.onChange(comp, name, val)
    }
    catch (Err e)
    {
      echo("ERROR: $this onChange")
      e.trace
    }
  }

  internal Void addChild(Str name, Comp child)
  {
    if (child.spi.parent != null) throw AlreadyParentedErr(child.typeof.qname)
    childSpi := (MCompSpi)child.spi
    childSpi.nameRef = name
    childSpi.parentRef = this.comp
    if (isMounted) cs.mount(child)
  }

  private Void removeChild(Comp child)
  {
    childSpi := (MCompSpi)child.spi
    childSpi.nameRef = ""
    childSpi.parentRef = null
    if (isMounted) cs.unmount(child)
  }

//////////////////////////////////////////////////////////////////////////
// Tree
//////////////////////////////////////////////////////////////////////////

  override Bool isMounted() { cs.readById(id, false) === comp }

  override Comp? parent() { parentRef }

  override Str name() { nameRef  }

  override Bool isBelow(Comp parent)
  {
    parent.isAbove(comp)
  }

  override Bool isAbove(Comp child)
  {
    Comp? p := child
    while (p != null)
    {
      if (p === comp) return true
      p = p.parent
    }
    return false
  }

  override Bool hasChild(Str name)
  {
    get(name) is CompObj
  }

  override Comp? child(Str name, Bool checked)
  {
    x := get(name) as CompObj
    if (x != null) return x
    if (checked) throw UnknownNameErr(name)
    return null
  }

  override Void eachChild(|Comp,Str| f)
  {
    each |v, n|
    {
      if (v is CompObj) f(v, n)
    }
  }

  override Links links()
  {
    Etc.links(get("links"))
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  override Void dump(Obj? opts)
  {
    doDump(Console.cur, comp, null, Etc.makeDict(opts))
  }

  private static Void doDump(Console con, Comp c, Str? name, Dict opts)
  {
    s := StrBuf()
    if (name != null) s.add(name).add(": ")
    s.add(c.spec.name).add(" @ ").add(c.id).add(" {")
    con.group(s.toStr)
    c.each |v, n|
    {
      if (n == "id" || n == "spec" || n == "dis") return
      if (isDefault(c, n, v)) return
      if (v is Comp) return doDump(con, v, n, opts)

      s.clear.add(n)
      if (v !==  Marker.val) s.add(": ").add(dumpValToStr(v))
      con.info(s.toStr)
    }
    con.groupEnd.info("}")
  }

  private static Bool isDefault(Comp c, Str name, Obj val)
  {
    slot := c.spec.slot(name, false)
    if (slot == null) return false
    def := slot.meta.get("val")
    if (slot.isList) return val is List && ((List)val).isEmpty
    return def == val
  }

  private static Str dumpValToStr(Obj val)
  {
    s := val.toStr
    if (s.size > 80) s = s[0..80]
    return "$s [$val.typeof]"
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  internal Comp? parentRef
  internal Str nameRef := ""
  private Str:Obj slots
}

