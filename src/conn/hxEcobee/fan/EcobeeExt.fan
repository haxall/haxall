//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   02 Feb 2022  Matthew Giannini  Creation
//

using haystack
using hx
using hxConn

**
** Ecobee connector library
**
const class EcobeeExt : ConnExt
{
  static EcobeeExt? cur(Bool checked := true)
  {
    Context.cur.proj.ext("hx.ecobee", checked)
  }
}

