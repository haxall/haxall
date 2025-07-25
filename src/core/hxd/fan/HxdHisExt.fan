//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Aug 2021  Brian Frank  Creation
//   25 Jul 2025  Brian Frank  Garden City (rework for 4.0)
//

using concurrent
using xeto
using haystack
using folio
using hx
using hxm
using hxFolio

**
** HxdHisExt provides simple wrapper around Folio as the
** implementation of the HxHisService.  Unlike SkySpark is does
** not currently support totalization, computed histories, etc.
**
internal const class HxdHisExt : ExtObj, IHisExt
{

  override Void read(Dict pt, Span? span, Dict? opts, |HisItem| f)
  {
    proj.db.his.read(pt.id, span, opts, f)
  }

  override Future write(Dict pt, HisItem[] items, Dict? opts := null)
  {
    proj.db.his.write(pt.id, items, opts)
  }

}

