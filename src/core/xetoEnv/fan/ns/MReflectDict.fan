//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Mar 2025  Brian Frank  Creation
//

using util
using xeto

**
** ReflectDict implementation
**
@Js
const class MReflectDict : ReflectDict
{
  new make(MNamespace ns, Dict subject, Spec recSpec)
  {
    // build map of all tags
    tags := Str:Obj?[:] { ordered = true }
    subject.each |v, n| { tags[n] = v }

    // merge in record spec slots that aren't defined
    choices := Str:SpecChoice[:]
    recSpec.slots.each |slot|
    {
      n := slot.name
      if (slot.isQuery) return
      if (slot.isChoice) choices[n] = ns.choice(slot)
      if (!tags.containsKey(n)) tags[n] = null
    }

    // pull out any choice markers into slots of Ref[]
    choices.each |c, n|
    {
      // find choice selections
      selections := c.selections(subject, false)

      // store choice "tag" as Spec[]
      // note: this code doesn't consider multiChoice validation
      tags[n] = selections.map |spec->Ref| { spec.id }

      // remove markers
      selections.each |sel|
      {
        SpecChoice.markers(sel).each |marker| { tags.remove(marker) }
      }
    }

    // now map to reflect slots
    acc := Str:ReflectSlot[:]
    acc.ordered = true
    tags.each |v, n|
    {
      slotSpec := recSpec.slot(n, false)
      if (slotSpec == null) slotSpec = ns.global(n, false)
      if (slotSpec == null) slotSpec = ns.specOf(v, false)
      if (slotSpec == null) slotSpec = ns.spec("sys::Obj")
      acc[n] = MReflectSlot(n, slotSpec, v)
    }

    this.subject     = subject
    this.spec        = recSpec
    this.slots       = acc.vals
    this.slotsByName = acc
  }

  override const Dict subject

  override const Spec spec

  override const ReflectSlot[] slots

  private const Str:ReflectSlot slotsByName

  override ReflectSlot? slot(Str name, Bool checked := true)
  {
    slot := slotsByName[name]
    if (slot != null) return slot
    if (checked) throw UnknownSlotErr(name)
    return null
  }

  override Void dump(Console con := Console.cur)
  {
    con.group("ReflectDict $subject.dis.toCode [$spec]")
    slots.each |slot| { con.info(slot.toStr) }
    con.groupEnd
  }

}

**************************************************************************
** MReflectSlot
**************************************************************************

**
** ReflectSlot implementation
**
 @Js
const class MReflectSlot : ReflectSlot
{
  new make(Str n, Spec s, Obj? v) { name = n; spec = s; val = v }

  override const Str name

  override const Spec spec

  override const Obj? val

  override Bool isChoice() { spec.isChoice }

  override Str toStr()
  {
    s := StrBuf()
    s.add(name)
    s.add(" [").add(spec).add("]")
    if (val != null) s.add(" = ").add(val)
    return s.toStr
  }
}

