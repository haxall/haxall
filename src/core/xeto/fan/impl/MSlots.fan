//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Feb 2023  Brian Frank  Creation
//

using data
using haystack::UnknownNameErr

**
** Implementation of DataSlots
**
@Js
internal const class MSlots : DataSlots
{
  static const MSlots empty := MSlots(Str:XetoSpec[:])

  new make(Str:XetoSpec map) { this.map = map }

  const Str:XetoSpec map

  override Bool isEmpty()
  {
    map.isEmpty
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

  override Void each(|DataSpec,Str| f)
  {
    map.each(f)
  }

  override Obj? eachWhile(|DataSpec,Str->Obj?| f)
  {
    map.eachWhile(f)
  }

  override Str toStr()
  {
    s := StrBuf()
    s.add("{")
    each |spec, name|
    {
      if (s.size > 1) s.add(", ")
      s.add(name)
    }
    return s.add("}").toStr
  }

}