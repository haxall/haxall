//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jun 2021  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hxStore

**
** HisMgr is the HxFolio implementation of FolioHis.  It uses a
** simple design to store history data in-memory as HisItem list.
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
      items.each(f)
    }
    else
    {
      items.each |item| { if (span.contains(item.ts)) f(item) }
    }
  }

  override FolioFuture write(Ref id, HisItem[] items, Dict? opts := null)
  {
    folio.checkWrite
    if (opts == null) opts = Etc.emptyDict

    // short circuit if no items and special opts
    if (items.isEmpty) return FolioFuture(HisWriteFolioRes.empty)

    // read current version of rec and do pre-write checks/normalization
    rec := folio.index.rec(id)
    dict := rec.dict
    items = FolioUtil.hisWriteCheck(dict, items, opts)

    // security check
    cx := FolioContext.curFolio(false)
    if (cx != null && !cx.canWrite(rec.dict)) throw PermissionErr("Cannot write: $id.toCode")

    // process on background thread for thread safety
    return FolioFuture(send(Msg(MsgId.hisWrite, rec, Unsafe(items), opts)))
  }

  internal override Obj? onReceive(Msg msg)
  {
    switch (msg.id)
    {
      case MsgId.hisWrite:  return onWrite(msg.a, msg.b, msg.c)
      default:              return super.onReceive(msg)
    }
  }

  private HisWriteFolioRes onWrite(Rec rec, Unsafe toWriteUnsafe, Dict opts)
  {
    // merge current and toWrite items
    toWrite := (HisItem[])toWriteUnsafe.val
    curItems := rec.hisItems
    newItems := FolioUtil.hisWriteMerge(curItems, toWrite)

    // clip to buffer size
maxItems := 1000  // TODO
    if (newItems.size > maxItems) newItems = newItems[newItems.size-maxItems..-1]
    newItems = newItems.toImmutable

    // update on IndexMgr for thread safety
    folio.index.hisUpdate(rec, newItems).get(null)

    return HisWriteFolioRes(Etc.makeDict1("count", Number(toWrite.size)))
  }
}