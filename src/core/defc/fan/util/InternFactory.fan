//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2020  Brian Frank  Creation
//

using haystack

**
** InternFactory
**
internal class InternFactory : HaystackFactory
{
  override Str makeId(Str s)
  {
    x := strs[s]
    if (x == null)
    {
      x = BrioConsts.cur.intern(s)
      strs[x] = x
    }
    return x
  }

  private Str:Str strs := [:]
}