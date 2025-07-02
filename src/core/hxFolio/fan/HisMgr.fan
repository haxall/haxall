//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jun 2021  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using hxStore

**
** HisMgr is the HxFolio implementation of FolioHis.  It uses a
** simple design to store history data in-memory as a HisItem list.
**
@NoDoc
const class HisMgr : HxFolioMgr, FolioHis
{
  new make(HxFolio folio) : super(folio)
  {
  }

  override Void read(Ref id, Span? span, Dict? opts, |HisItem| f)
  {
    // read checks
    folio.checkRead
    if (opts == null) opts = Etc.emptyDict

    // read current version of rec and do check security
    rec := folio.index.rec(id)
    cx := FolioContext.curFolio(false)
    if (cx != null && !cx.canRead(rec.dict)) throw PermissionErr("Cannot read: $id.toCode")

    // config checks
    dict := rec.dict
    if (dict.missing("point") || dict.missing("his")) throw HisConfigErr(dict, "Not tagged as his point")
    if (dict.has("aux")) throw HisConfigErr(dict, "Cannot read aux point")
    if (dict.has("trash")) throw HisConfigErr(dict, "Cannot read from trash")

    // store immutable list of items to local variable
    items := rec.hisItems

    // iterate the items
    if (span == null)
    {
      // iterate all the items we have
      items.each(f)
    }
    else
    {
      // implement SkySpark's behavior to always provide the previous and next two items
      HisItem? prev := null
      next := 0
      items.each |item|
      {
        if (item.ts < span.start)
        {
          prev = item
        }
        else if (item.ts >= span.end)
        {
          if (next < 2)
          {
            f(item)
            next++
          }
        }
        else
        {
          if (prev != null) { f(prev); prev = null }
          f(item)
        }
      }
    }
  }

  override FolioFuture write(Ref id, HisItem[] items, Dict? opts := null)
  {
    folio.checkWrite

    // force unitSet opt to ensure we always store items with unit
    opts = Etc.dictSet(opts, "unitSet", Marker.val)

    // short circuit if no items and special opts
    if (items.isEmpty) return FolioFuture(HisWriteFolioRes.empty)

    // read current version of rec and do pre-write checks/normalization
    rec := folio.index.rec(id)
    dict := rec.dict
    items = FolioUtil.hisWriteCheck(dict, items, opts)

    // security check
    cx := FolioContext.curFolio(false)
    if (cx != null && !cx.canWrite(rec.dict)) throw PermissionErr("Cannot write: $id.toCode")

    // process on IndexMgr thread for thread safety
    return FolioFuture(folio.index.hisWrite(rec, items, opts, cx?.commitInfo))
  }
}

**************************************************************************
** HisEvent
**************************************************************************

internal class HisEvent : FolioHisEvent
{
  new make(Dict rec, Dict result, Obj? cxInfo)
  {
    this.rec = rec
    this.result = result
    this.cxInfo = cxInfo
  }

  override const Dict rec
  override const Dict result
  override const Obj? cxInfo
}

