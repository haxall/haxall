//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Jun 2019  Brian Frank  Creation
//

using concurrent
using haystack

**
** CellDef data flow component cell and its metadata
**
@Js
const mixin CellDef : Dict
{
  ** Parent component def
  abstract CompDef parent()

  ** Cell name
  abstract Str name()

  ** Cell index into CompDef.cells
  @NoDoc abstract Int index()
}







