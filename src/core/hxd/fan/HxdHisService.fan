//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Aug 2021  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using hx
using hxFolio

**
** HxdHisService provides simple wrapper around Folio as the
** implementation of the HxHisService.  Unlike SkySpark is does
** not currently support totalization, computed histories, etc.
**
internal const class HxdHisService : HxHisService
{
  new make(HxdRuntime rt) { this.rt = rt }

  const HxdRuntime rt

  override Void read(Dict pt, Span? span, Dict? opts, |HisItem| f)
  {
    rt.db.his.read(pt.id, span, opts, f)
  }

  override Future write(Dict pt, HisItem[] items, Dict? opts := null)
  {
    rt.db.his.write(pt.id, items, opts)
  }

}

