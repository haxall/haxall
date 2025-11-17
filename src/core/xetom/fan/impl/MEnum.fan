//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Dec 2023  Brian Frank  Creation
//

using util
using xeto
using haystack

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
    defKey := null
    enum.slots.each |x|
    {
      key := x.meta["key"] as Str ?: x.name
      if (defKey == null) defKey = key
      acc.add(key, x)
    }
    return make(acc, defKey)
  }

  private new make(Str:Spec map, Str defKey)
  {
    this.map = map
    this.defKey = defKey
  }

  const Str:Spec map

  override Spec? spec(Str key, Bool checked := true)
  {
    spec := map[key]
    if (spec != null) return spec
    if (checked) throw UnknownNameErr("Unknown enum key '$key'")
    return null
  }

  const Str defKey

  override Str[] keys()
  {
    map.keys
  }

  override Void each(|Spec,Str| f)
  {
    map.each(f)
  }

  override Dict? xmeta(Str? key := null, Bool checked :=true)
  {
    throw UnsupportedErr("Must call Namespace.xmetaEnum")
  }

}

**************************************************************************
** MEnumXMeta
**************************************************************************

@Js
const final class MEnumXMeta : SpecEnum
{
  new make(MEnum enum, Dict xmetaSelf, Str:Dict xmetaByKey)
  {
    this.enum        = enum
    this.xmetaSelf  = xmetaSelf
    this.xmetaByKey = xmetaByKey
  }

  override Spec? spec(Str key, Bool checked := true)
  {
    enum.spec(key, checked)
  }

  override Str[] keys()
  {
    enum.keys
  }

  override Void each(|Spec,Str| f)
  {
    enum.each(f)
  }

  override Dict? xmeta(Str? key := null, Bool checked :=true)
  {
    if (key == null) return xmetaSelf
    x := xmetaByKey.get(key)
    if (x != null) return x
    if (checked) throw UnknownNameErr("Unknown enum key '$key'")
    return null
  }

  const MEnum enum
  const Dict xmetaSelf
  const Str:Dict xmetaByKey
}

