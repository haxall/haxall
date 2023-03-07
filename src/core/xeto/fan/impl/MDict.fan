//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Feb 2023  Brian Frank  Creation (yet again)
//

using data
using haystack::UnknownNameErr

**
** Implementation of DataDict
**
@Js
internal const class MDict : DataDict
{
  new make(Str:Obj map, DataSpec? spec)
  {
    this.map = map
    this.specRef = spec
  }

  const Str:Obj map

  const DataSpec? specRef

  override DataSpec spec() { specRef ?: DataEnv.cur.dictSpec }

  override Bool isEmpty()
  {
    map.isEmpty
  }

  @Operator override Obj? get(Str name, Obj? def := null)
  {
    map.get(name, def)
  }

  override Bool has(Str name)
  {
    map.get(name) != null
  }

  override Bool missing(Str name)
  {
    map.get(name) == null
  }

  override Void each(|Obj val, Str name| f)
  {
    map.each(f)
  }

  override Obj? eachWhile(|Obj val, Str name->Obj?| f)
  {
    map.eachWhile(f)
  }

  override Obj? trap(Str name, Obj?[]? args := null)
  {
    x := map.get(name, null)
    if (x != null) return x
    throw UnknownNameErr(name)
  }

  override Str toStr()
  {
    s := StrBuf()
    s.add("{")
    each |v, n|
    {
      if (s.size > 1) s.add(", ")
      s.add(n)
//      if (v !== DataEnv.cur.marker) s.add(":").add(v)
    }
    return s.add("}").toStr
  }
}