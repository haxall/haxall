//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Dec 2023  Brian Frank  Creation
//

using util
using xeto
using haystack::UnknownNameErr

**
** Implementation of SpecEnum
**
@Js
const final class MEnum : SpecEnum
{
  static MEnum init(MType enum)
  {
    acc := Str:Spec[:]
    acc.ordered = true
    enum.slots.each |x|
    {
      key := x.meta["key"] as Str ?: x.name
      acc.add(key, x)
    }
    return make(acc)
  }

  private new make(Str:Spec map) { this.map = map }

  const Str:Spec map

  override Spec? spec(Str key, Bool checked := true)
  {
    spec := map[key]
    if (spec != null) return spec
    if (checked) throw UnknownNameErr("Unknown enum key '$key'")
    return null
  }

  override Str[] keys()
  {
    map.keys
  }

  override Void each(|Spec,Str| f)
  {
    map.each(f)
  }
}