//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Oct 2021  Matthew Giannini  Creation
//

using util

**
** Utility class for building a "filters" query parameter
**
class Filters
{
  new make() { }

  private [Str:Str[]] filters := [:]

  This withFilter(Str key, Str[] vals)
  {
    filters.getOrAdd(key) |->Str[]| { Str[,] }.addAll(vals)
    return this
  }

  // TODO: more utilities for common filter encoding

  Str? build()
  {
    if (filters.isEmpty) return null
    return JsonOutStream.writeJsonToStr(filters)
  }
}