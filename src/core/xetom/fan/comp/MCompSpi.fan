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

  override Int ver { internal set }

  override Str dis() { get("dis") ?: toStr }

  override Str toStr()
  {
    "$name @$id [$spec.qname]"
  }

//////////////////////////////////////////////////////////////////////////
// Slots
//////////////////////////////////////////////////////////////////////////

  override Obj? get(Str name)
  {
    x := slots.get(name)
    if (x== null) return null
    return slotVal(x)
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
    slots.each |x, n|
    {
      v := slotVal(x)
      if (v != null) f(v, n)
    }
  }

  override Obj? eachWhile(|Obj,Str->Obj?| f)
  {

    slots.eachWhile |x, n|
    {
      v := slotVal(x)
      if (v != null) return f(v, n)
      else return null
    }
  }

  Obj? slotVal(Obj v)
  {
    v.typeof === FatSlot.type ? ((FatSlot)v).val : v
  }

//////////////////////////////////////////////////////////////////////////
// FatSlot Support
//////////////////////////////////////////////////////////////////////////

  Void eachFat(|FatSlot, Str| f)
  {
    slots.each |x, n|
    {
      if (x.typeof === FatSlot.type) f(x, n)
    }
  }

  Bool isFat(Str name)
  {
    slots.get(name) is FatSlot
  }

  FatSlot fatten(Str name)
  {
    x := slots.get(name)
    if (x is FatSlot) return x
    fs := FatSlot(x)
    slots.set(name, fs)
    return fs
  }

  internal Void clearPushTo()
  {
    slots.each |x|
    {
      (x as FatSlot)?.clearPushTo
    }
  }

//////////////////////////////////////////////////////////////////////////
// Updates
//////////////////////////////////////////////////////////////////////////

  override Void reorder(Str[] newOrder)
  {
    // create new map in given new order
    oldSlots := this.slots
    newSlots := Str:Obj[:]
    newSlots.ordered = true
    newOrder.each |n|
    {
      v := oldSlots[n] ?: throw ArgErr("Slot name not defined: $n")
      newSlots[n] = v
    }

    // need to add back in fat methods that don't have value
    oldSlots.each |v, n|
    {
      fat := v as FatSlot
      if (fat != null && fat.val == null) newSlots.add(n, fat)
    }

    // sanity check the size
    if (oldSlots.size != newSlots.size)
      throw ArgErr("Names size does not match current slots size: $newSlots.size != $oldSlots.size")

    this.slots = newSlots
    changed(CompChangeEvent(comp, "reorder!", null, null, null))
  }

  override Void add(Obj val, Str? name)
  {
    if (name != null)
    {
      if (has(name)) throw DuplicateNameErr(name)
    }
    else
    {
      name = autoName
    }
    set(name, val)
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
    set(name, null)
  }

  override Void set(Str name, Obj? newVal)
  {
    // lookup slot
    slot := spec.slot(name, false)

    if (name == "id" || name == "spec")
      throw InvalidChangeErr("'$name' may not be modified")

    // lookup old value/fat slot
    oldVal := slots.get(name)
    fat := oldVal as FatSlot
    if (fat != null) oldVal = fat.val

    // short circuit if reference to same object
    if (oldVal === newVal) return

    // if adding new slot then check name
    if (oldVal == null && !Etc.isTagName(name)) throw InvalidNameErr(name)

    // unmount comp
    if (oldVal is Comp) removeChild(oldVal)

    // mount new comp or ensure immutable
    if (newVal is Comp) addChild(name, newVal)
    else newVal = newVal.toImmutable

    // update slot map
    if (newVal != null)
    {
      // set in my map
      if (fat == null) slots.set(name, newVal)
      else fat.set(newVal)
    }
    else
    {
      // remove
      if (slot != null && !slot.isMaybe) throw InvalidChangeErr("'$name' may not be removed")
      slots.remove(name)
    }

    // fire callback
    changed(CompChangeEvent(comp, name, slot, oldVal, newVal))
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

  // Choke point for all slot changes
  // Reorder passes "reorder!" for name
  private Void changed(CompChangeEvent event)
  {
    try
    {
      // special callback
      comp.onChangeFw(event)

      // standard callback
      comp.onChange(event)

      // space level callback
      if (isMounted) cs.change(this, event)
    }
    catch (Err e)
    {
      echo("ERROR: $this onChange")
      e.trace
    }
  }

//////////////////////////////////////////////////////////////////////////
// Methods & Call
//////////////////////////////////////////////////////////////////////////

  override Bool hasMethod(Str name)
  {
    slot := spec.slot(name, false)
    return slot != null && slot.isFunc
  }

  override Obj? call(Str name, Obj? arg)
  {
    res := spec.slot(name).func.thunk.callList([comp, arg])

    fat := slots.get(name) as FatSlot
    if (fat != null)
    {
      fat.called(res)
      execute
    }

    return res
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
    get("links") ?: Etc.links(null)
  }

//////////////////////////////////////////////////////////////////////////
// Execution
//////////////////////////////////////////////////////////////////////////

  ** Set the needsExecute flag for next cycle
  override Void execute()
  {
    needsExecute = true
  }

  ** Check if timer has elapsed
  internal Void checkTimer(DateTime now)
  {
    // short circuit if frequency null
    freq := comp.onExecuteFreq
    if (freq == null) return

    // if first call then init lastOnTimer ticks
    ticks := now.ticks
    if (lastOnTimer <= 0) { this.lastOnTimer = ticks; return }

   // check if freq has elapsed
    elapsed := ticks - lastOnTimer
    if (elapsed < freq.ticks) return

    // needs execute
    this.lastOnTimer = ticks
    this.needsExecute = true
  }

  ** Execute the component
  internal Void checkExecute(CompContext cx)
  {
    if (!needsExecute) return
    needsExecute = false
    try
    {
      comp.onExecute
    }
    catch (Err e)
    {
      echo("ERROR: ${comp.typeof.name}.onExecute")
      e.trace
    }
    pushLinks
  }

  ** Push all my linked slots
  private Void pushLinks()
  {
    eachFat |fat| { fat.push }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  override Void dump(Console? con, Obj? opts)
  {
    if (con == null) con = Console.cur
    if (opts is Str) opts = opts.toStr.split(',')
    optsDict := Etc.makeDict(opts)

    if (optsDict.has("xeto"))
    {
      xeto := CompUtil.compSaveToXeto(cs.ns, comp)
      con.info(xeto)
      return
    }

    doDump(con, comp, null, optsDict)
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
  internal Bool needsExecute := true
  private Str:Obj slots
  private Int lastOnTimer
}

