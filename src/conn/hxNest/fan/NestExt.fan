//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jan 2022  Matthew Giannini  Creation
//

using haystack
using hx
using hxConn

**
** Nest connector library
**
const class NestExt : ConnExt
{
  static NestExt? cur(Bool checked := true)
  {
    HxContext.curHx.rt.libsOld.get("nest", checked)
  }
}

