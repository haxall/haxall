//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Feb 2023  Brian Frank  Creation
//

using xeto
using haystack::Dict
using haystack::UnknownNameErr

**
** Implementation of DataSlots
**
@Js
internal const final class MSlots : DataSlots
{
  static const MSlots empty := MSlots(Str:XetoSpec[:])

  new make(Str:XetoSpec map) { this.map = map }

  const Str:XetoSpec map

  override Bool isEmpty()
  {
    map.isEmpty
  }

  override Bool has(Str name)
  {
    map.containsKey(name)
  }

  override Bool missing(Str name)
  {
    !map.containsKey(name)
  }

  override XetoSpec? get(Str name, Bool checked := true)
  {
    kid := map[name]
    if (kid != null) return kid
    if (!checked) return null
    throw UnknownNameErr(name)
  }

  override Str[] names()
  {
    map.keys
  }

  override Void each(|DataSpec| f)
  {
    map.each(f)
  }

  override Obj? eachWhile(|DataSpec->Obj?| f)
  {
    map.eachWhile(f)
  }

  override Str toStr()
  {
    s := StrBuf()
    s.add("{")
    each |slot|
    {
      if (s.size > 1) s.add(", ")
      s.add(slot.name)
    }
    return s.add("}").toStr
  }

  override Dict toDict()
  {
    MSlotsDict(this)
  }
}

**************************************************************************
** MSlotsDict
**************************************************************************

@Js
internal const class MSlotsDict : Dict
{
  new make(MSlots slots) { this.slots = slots }

  const MSlots slots

  @Operator override Obj? get(Str n, Obj? def := null) { slots.get(n, false) ?: def }
  override Bool isEmpty() { slots.isEmpty }
  override Bool has(Str n) { slots.get(n, false) != null }
  override Bool missing(Str n) {  slots.get(n, false) == null }
  override Void each(|Obj, Str| f) { slots.map.each(f) }
  override Obj? eachWhile(|Obj, Str->Obj?| f) { slots.map.eachWhile(f) }
  override Obj? trap(Str n, Obj?[]? a := null) { slots.get(n, true) }
}