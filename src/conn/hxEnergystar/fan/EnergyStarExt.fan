//
// Copyright (c) 2013, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jun 13    Brian Frank  Creation
//   14 Aug 2025  Brian Frank  Open source for 4.0
//

using hx
using hxConn

**
** Energy Star Extension
** NOTE: this will only work in SkySpark
**
const class EnergyStarExt : ConnExt
{

//////////////////////////////////////////////////////////////////////////
// Current
//////////////////////////////////////////////////////////////////////////

  ** Get EnergyStarExt for the current context.
  static EnergyStarExt? cur(Bool checked := true)
  {
    Context.cur.ext("hx.energystar", checked)
  }

  override Str modelName() { "energyStar" }
}

