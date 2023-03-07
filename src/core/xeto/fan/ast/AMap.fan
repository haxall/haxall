//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jan 2023  Brian Frank  Creation
//

using util

**
** AST map of name/object pairs
**
@Js
internal class AMap
{

  ** Empty map means we parsed an empty "<>" or "{}"
  Bool isEmpty() { map.isEmpty }

  ** Number of pairs
  Int size() { map.size }

  ** Add a name/object pair - should check for duplicates before
  ** calling this method to properly report the duplicate name error
  Void add(AObj obj)
  {
    if (map.isEmpty)
    {
      map = Str:AObj[:]
      map.ordered = true
    }
    map.add(obj.name, obj)
  }

  ** Get a pair by name or null
  AObj? get(Str name) { map[name] }

  ** Remove object by name
  AObj? remove(Str name)
  {
    if (map.isEmpty) return null
    return map.remove(name)
  }

  ** Iterate the name/object pairs
  Void each(|AObj, Str| f) { map.each(f) }

  ** Walk the AST objects
  Void walk(|AObj| f) { map.each |x| { x.walk(f) } }

  ** Debug string
  override Str toStr()
  {
    s := StrBuf()
    map.each |v, n| { s.join(n, ", ").add(":").add(v) }
    return s.toStr
  }

  private static const Str:AObj empty := [:]

  private Str:AObj map := empty
}