//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Jan 2010  Brian Frank  Creation
//   4 Jan 2010  Brian Frank  Rename from haystack::Remove
//

**
** None is the singleton which indicates the absense of a value.
**
@Js
const final class None
{
  ** Singleton value
  const static None val := None()

  private new make() {}

  ** Return U+2205 "∅"
  override Str toStr() { "\u2205" }
}

