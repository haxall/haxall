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
      doSet(name, get(name), val)
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
    doSet(name, null, val)
  }

  private Void checkSet(Str name, Obj val)
  {
    if (CompUtil.isReservedSlot(name))
      throw InvalidChangeErr("'$name' may not be modified")

    slot := spec.slot(name, false)
    if (slot == null) return null

    // map value to spec
    /* TODO
    valSpec := val is Comp ? ((Comp)val).spec : cs.ns.specOf(val)
    if (!isValidSlotVal(slot, val, valSpec))
      throw InvalidChangeErr("Invalid type for $slot.qname: $slot.type != $valSpec")
    */
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
          doSet(name, null, MethodFunction(method))
          return
        }
      }

      throw InvalidChangeErr("$slot.qname is required")
    }

    doRemove(name)
  }

  private Void doSet(Str name, Obj? oldVal, Obj newVal)
  {
    if (oldVal === newVal) return // short circuit if same
    if (oldVal is Comp) removeChild(oldVal)
    if (newVal is Comp) addChild(name, newVal)
    else if (newVal isnot Function) newVal = newVal.toImmutable
    slots.set(name, newVal)
    changed(name, newVal)
  }

  private Void doRemove(Str name)
  {
    val := slots.remove(name)
    if (val is Comp) removeChild(val)
    changed(name, null)
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

  override Void reorder(Str[] newOrder)
  {
    oldSlots := this.slots
    newSlots := Str:Obj[:]
    newSlots.ordered = true
    newOrder.each |n|
    {
      v := oldSlots[n] ?: throw ArgErr("Slot name not defined: $n")
      newSlots[n] = v
    }
    if (oldSlots.size != newSlots.size)
      throw ArgErr("Names size does not match current slots size: $newSlots.size != $oldSlots.size")
    this.slots = newSlots
    changed("reorder!", null)
  }

//////////////////////////////////////////////////////////////////////////
// Callbacks
//////////////////////////////////////////////////////////////////////////

  // Choke point for all slot changes
  // Reorder passes "reorder!" for name
  private Void changed(Str name, Obj? newVal)
  {
    try
    {
      // special callback
      comp.onChangeFw(name, newVal)

      // standard callback
      comp.onChange(name, newVal)

      // space level callback
      if (isMounted) cs.change(this, name, newVal)
    }
    catch (Err e)
    {
      echo("ERROR: $this onChange")
      e.trace
    }
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
    pullLinks
    try
    {
      comp.onExecute
    }
    catch (Err e)
    {
      echo("ERROR: ${comp.typeof.name}.onExecute")
      e.trace
    }
  }

  ** Pull all links
  private Void pullLinks()
  {
    links.eachLink |toSlot, link| { pullLink(toSlot, link) }
  }

  ** Pull given link
  private Void pullLink(Str toSlot, Link link)
  {
    // lookup from component
    fromComp := cs.readById(link.fromRef, false)
    if (fromComp == null) return

    // lookuip from slot value
    val := fromComp.get(link.fromSlot)
    if (val == null) return val

    // pull to my own slot
    set(toSlot, val)
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

