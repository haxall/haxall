//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Feb 2016  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hxStore

**
** IndexMgr is responsible for the in-memory index of Recs.
** All changes to Rec and their lookup tables are handled by
** the index actor.
**
internal const class IndexMgr : HxFolioMgr
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructro
  new make(HxFolio folio, Loader loader) : super(folio)
  {
    this.byId = loader.byId
  }

//////////////////////////////////////////////////////////////////////////
// Reads
//////////////////////////////////////////////////////////////////////////

  ** Number of records
  Int size()  { byId.size }

  ** Lookup Rec by id
  Rec? rec(Ref ref, Bool checked := true)
  {
    rec := byId.get(ref)
    if (rec != null) return rec
    if (ref.isRel && folio.idPrefix != null)
    {
      ref = ref.toAbs(folio.idPrefix)
      rec = byId.get(ref)
      if (rec != null) return rec
    }
    if (checked) throw UnknownRecErr(ref.id)
    return null
  }

  ** Lookup Rec.dict by id
  Dict? dict(Ref ref, Bool checked := true)
  {
    rec(ref, checked)?.dict
  }

//////////////////////////////////////////////////////////////////////////
// Background Updates
//////////////////////////////////////////////////////////////////////////

  private DateTime lastMod() { lastModRef.val }
  private const AtomicRef lastModRef := AtomicRef(DateTime.nowUtc)

  Future commit(Diff[] diffs) { send(Msg(MsgId.commit, diffs)) }

  Future hisWrite(Rec rec, HisItem[] items, Dict? opts, Obj? cxInfo) { send(Msg(MsgId.hisWrite, rec, Unsafe(items), opts, cxInfo)) }

  override Obj? onReceive(Msg msg)
  {
    switch (msg.id)
    {
      case MsgId.commit:    return onCommit(msg.a, msg.b, msg.c)
      case MsgId.hisWrite:  return onHisWrite(msg.a, msg.b, msg.c, msg.d)
      default:              return super.onReceive(msg)
    }
  }

  private Rec onHisUpdate(Rec rec, HisItem[] items)
  {
    rec.hisUpdate(items)
  }

//////////////////////////////////////////////////////////////////////////
// Commit
//////////////////////////////////////////////////////////////////////////

  private CommitFolioRes onCommit(Diff[] diffs, [Ref:Ref]? newIds, Obj? cxInfo)
  {
    // all diffs are transient or peristent (checked ealier)
    persistent := !diffs.first.isTransient

    // generate a new unique mod
    newMod := DateTime.nowUtc(null)
    if (newMod <= lastMod) newMod = lastMod + 1ms

    // map each diffs to Commit instance
    newTicks := Duration.nowTicks
    Commit[] commits := diffs.map |d->Commit| { Commit(folio, d, newMod, newTicks, newIds, cxInfo) }

    // perform up-front verification
    commits.each |c| { c.verify }

    // apply to in-memory data models and lookup tables
    try
    {
      diffs = commits.map |c->Diff| { c.apply }
    }
    catch (Err e)
    {
      log.err("Commit failed", e)
      throw e
    }

    // update our lastMod if peristent batch of diffs
    if (persistent) lastModRef.val = newMod

    // if adding more than one rec at once, refresh ref dis
    if (newIds != null && newIds.size > 1) folio.disMgr.updateAll

    return CommitFolioRes(diffs)
  }

//////////////////////////////////////////////////////////////////////////
// His Write
//////////////////////////////////////////////////////////////////////////

  private HisWriteFolioRes onHisWrite(Rec rec, Unsafe toWriteUnsafe, Dict opts, Obj? cxInfo)
  {
    // merge current and toWrite items
    toWrite := (HisItem[])toWriteUnsafe.val
    curItems := rec.hisItems
    newItems := FolioUtil.hisWriteMerge(curItems, toWrite)

    // clip to buffer size
    maxItems := hisMaxItems(rec.dict)
    if (newItems.size > maxItems) newItems = newItems[newItems.size-maxItems..-1]
    newItems = newItems.toImmutable

    // update hisSize, hisStart, hisEnd tags
    rec.hisUpdate(newItems)

    // compute result
    span := Span(toWrite.first.ts, toWrite.last.ts)
    result := Etc.makeDict2("count", Number(toWrite.size), "span", span)

    // fire hooks event
    folio.hooks.postHisWrite(HisEvent(rec.dict, result, cxInfo))

    return HisWriteFolioRes(result)

  }

  private Int hisMaxItems(Dict rec)
  {
    Etc.dictGetInt(rec, "hisMaxItems", 1000)
  }

  internal Void hisTagsModified(Rec rec)
  {
    try
    {
      // get current items
      curItems := rec.hisItems
      if (curItems.isEmpty) return

      // gather new configuration
      dict := rec.dict
      tz := FolioUtil.hisTz(dict)
      unit := FolioUtil.hisUnit(dict)
      kind := FolioUtil.hisKind(dict)
      isNum := kind.isNumber

      // try to short circuit if nothing actually changed
      sample := curItems.first
      if (sample.ts.tz == tz && (sample.val as Number)?.unit == unit) return

      // map items
      newItems := curItems.map |item->HisItem|
      {
        ts := item.ts.toTimeZone(tz)
        val := item.val
        if (isNum) val = Number(((Number)val).toFloat, unit)
        return HisItem(ts, val)
      }

      // update the record
      newItems = newItems.toImmutable
      rec.hisUpdate(newItems)
    }
    catch (Err e)
    {
      folio.log.err("HisMgr.onUpdate: $rec.id.toZinc", e)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  internal const ConcurrentMap byId    // mutate only by Commit on this thread
}


