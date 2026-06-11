//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Jun 2026  Brian Frank  Creation
//

**
** StrTable maps strings to dense zero-based indices.
** Duplicate adds with same string return the existing index.
**
@Js
class StrTable
{
  ** Number of unique strings
  Int size() { list.size }

  ** Add a string, return its index.  If already added return existing index.
  Int add(Str s)
  {
    idx := map[s]
    if (idx != null) return idx
    idx = list.size
    map[s] = idx
    list.add(s)
    return idx
  }

  ** Get index for string or throw
  Int get(Str s) { map[s] ?: throw ArgErr("Unknown: $s") }

  ** Get string by index
  Str str(Int index) { list[index] }

  ** Iterate strings in insertion order
  Void each(|Str, Int| f) { list.each(f) }

  private Str[] list := [,]
  private Str:Int map := [:]
}

