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
const class EcobeeLib : ConnLib
{
  static EcobeeLib? cur(Bool checked := true)
  {
    HxContext.curHx.rt.libsOld.get("ecobee", checked)
  }
}

