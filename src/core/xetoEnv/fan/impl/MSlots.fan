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
** Implementation of SpecSlots
**
@Js
const final class MSlots : SpecSlots
{
  static const MSlots empty := MSlots(NameDict.empty)

  new make(NameDict map) { this.map = map }

  const NameDict map

  Int size() { map.size }

  override Bool isEmpty()
  {
    map.isEmpty
  }

  override Bool has(Str name)
  {
    map.has(name)
  }

  override Bool missing(Str name)
  {
    map.missing(name)
  }

  override XetoSpec? get(Str name, Bool checked := true)
  {
    kid := map.get(name)
    if (kid != null) return kid
    if (!checked) return null
    throw UnknownNameErr(name)
  }

  override Str[] names()
  {
    acc := Str[,]
    acc.capacity = map.size
    map.each |v, n| { acc.add(n) }
    return acc
  }

  override Void each(|Spec,Str| f)
  {
    map.each(f)
  }

  override Obj? eachWhile(|Spec,Str->Obj?| f)
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

