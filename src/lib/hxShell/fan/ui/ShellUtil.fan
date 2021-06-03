//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Jun 2021  Brian Frank  Creation
//

using dom
using domkit
using haystack

**
** ShellView is used to display the current grid
**
@Js
internal const class ShellUtil
{
  static Str valToDis(Obj? val)
  {
    if (val is Ref) return ((Ref)val).toZinc
    return Etc.valToDis(val)
  }
}