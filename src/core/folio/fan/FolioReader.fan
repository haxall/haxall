//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jul 2026  Matthew Giannini  Creation
//    5 Aug 2026  Brian Frank  Rename FolioReadSink -> FolioReader
//

using concurrent
using xeto
using haystack

**
** FolioReader manages one read operation against the database.  It owns
** all read option handling, trash exclusion, permission checking, error
** priority, and result materialization.
**
** For filter reads the subclass streams every raw rec matching its
** filter into `accept` and lets the reader decide what survives;
** `accept` and `prepCapacity` are the only members a subclass may use.
**
** For by-id reads the base class feeds the raw recs to `checkRecs`.
**
** A reader is single use; it carries the state of one read operation.
**
** A reader with a limit of zero must never be streamed into - `accept`
** would yield one rec before it could stop.  Folio short circuits that
** case so it never reaches a store, which keeps the check out of the
** per-rec path.
**
@NoDoc final class FolioReader
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Reader which routes accepted recs to the given callback
  new make(FolioContext? cx, Dict? opts, |Dict->Obj?| f)
  {
    o := opts ?: Etc.dict0
    this.cx     = cx
    this.limit  = (o.get("limit") as Number)?.toInt ?: Int.maxVal
    this.search = Filter.searchFromOpts(o)
    this.sort   = o.has("sort")
    this.f      = f
  }

  ** Reader which accumulates accepted recs; errMsgObj is used for
  ** the error message when a checked result is empty
  static FolioReader makeAccumulate(FolioContext? cx, Dict? opts, Obj errMsgObj)
  {
    acc := Dict[,]
    r := FolioReader(cx, opts) |Dict rec->Obj?| { acc.add(rec); return null }
    r.list = acc
    r.errMsgObj = errMsgObj
    return r
  }

  ** Reader for by-id reads; feed the raw recs via `checkRecs`
  new makeByIds(FolioContext? cx, Ref[] ids, Bool includeTrash := false)
  {
    this.cx           = cx
    this.ids          = ids
    this.includeTrash = includeTrash
    this.limit        = Int.maxVal
    this.f            = noopFunc
  }

  ** Reader which only counts recs; backs the default doReadCount.  Applies
  ** no options and no permission checks - the base class only counts this
  ** way when neither is required.
  new makeCount()
  {
    this.limit = Int.maxVal
    this.f     = noopFunc
  }

//////////////////////////////////////////////////////////////////////////
// Scan
//////////////////////////////////////////////////////////////////////////

  ** Hint that addingSize more recs are about to be offered so that
  ** the accumulator list can be pre-sized
  Void prepCapacity(Int addingSize)
  {
    list := this.list
    if (list == null) return
    total := list.size + addingSize
    if (total > limit) total = limit
    list.capacity = total
  }

  ** Number of recs which passed every check.
  Int count { private set }

  ** Non-null result returned by the callback; see `count` on visibility
  Obj? result { private set }

  ** Offer one raw rec to the reader. Return non-null if the store should
  ** stop streaming, in which case the store must return that value from
  ** its eachWhile hook.
  Obj? accept(Dict rec)
  {
    // stay stopped even if the store ignored a previous stop
    if (stop != null) return stop

    // skip recs we cannot read or which fail the search filter
    if (cx != null && !cx.canRead(rec)) return null
    if (search != null && !search.matches(rec, HaystackContext.nil)) return null

    // rec passed every check, so it counts against the limit
    ++count
    r := f(rec)
    if (r != null) { result = r; stop = r; return r }
    if (count >= limit) { stop = breakVal; return breakVal }
    return null
  }

//////////////////////////////////////////////////////////////////////////
// By Id
//////////////////////////////////////////////////////////////////////////

  ** Apply trash exclusion and permission checks to one raw rec read by
  ** id.  This is the fast path for readRecById which allocates no reader.
  static FolioRec? checkRec(FolioContext? cx, FolioRec? rec, Ref id, Bool checked)
  {
    // do not return trash recs
    if (rec != null && rec.isTrash) rec = null
    if (rec == null)
    {
      if (checked) throw UnknownRecErr(id.toZinc)
      return null
    }
    if (cx != null && !cx.canRead(rec.dict))
    {
      if (checked) throw PermissionErr("Cannot read: ${id.toZinc}")
      return null
    }
    return rec
  }

  ** Apply trash exclusion, permission checks, and error priority to the
  ** raw recs read for `makeByIds`; the recs match the ids by index
  This checkRecs(FolioRec?[] recs)
  {
    denied := false
    ids.each |id, i|
    {
      rec := recs[i]

      // do not return trash recs
      if (rec != null && rec.isTrash && !includeTrash) recs[i] = rec = null

      if (rec == null)
      {
        // only the first missing rec is reported, but permission errs get priority
        if (err == null) err = UnknownRecErr(id.toZinc)
      }
      else if (cx != null && !cx.canRead(rec.dict))
      {
        recs[i] = null

        // a permission error always wins over a missing rec
        if (!denied) { denied = true; err = PermissionErr("Cannot read: ${id.toZinc}") }
      }
    }
    this.byIdRecs = recs
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Results
//////////////////////////////////////////////////////////////////////////

  ** Get by-id results as rec wrappers; matches the ids by index with
  ** null for recs not found or not readable
  FolioRec?[] recs(Bool checked := true)
  {
    if (checked && err != null) throw err
    return byIdRecs
  }

  ** Get first by-id result as rec wrapper
  FolioRec? rec(Bool checked := true)
  {
    rec := byIdRecs.getSafe(0)
    if (rec != null) return rec
    if (checked) throw toErr
    return null
  }

  ** Get results as dicts; by-id results match the ids by index with
  ** null for recs not found or not readable
  Dict?[] dicts(Bool checked := true)
  {
    if (checked && err != null) throw err
    recs := byIdRecs
    if (recs != null) return recs.map |rec->Dict?| { rec?.dict }
    return scanResults
  }

  ** Get the first result as a Dict.  If there are no results then
  ** raise an exception or return null based on checked flag.
  Dict? dict(Bool checked := true)
  {
    dict := dicts(false).getSafe(0)
    if (dict != null) return dict
    if (checked) throw toErr
    return null
  }

  ** Get results as grid with support for standard read opts
  Grid grid(Dict? opts, Bool checked)
  {
    Etc.makeDictsGrid(opts?.get("gridMeta"), dicts(checked))
  }

  ** Error to raise for a checked read which found nothing
  private Err toErr() { err ?: UnknownRecErr(errMsgObj?.toStr ?: "") }

  ** Accumulated scan results with the sort option applied
  private Dict[] scanResults()
  {
    list := this.list ?: throw Err("Reader is not accumulate mode")
    if (sort && !sorted) { list = Etc.sortDictsByDis(list); this.list = list; sorted = true }
    return list
  }

//////////////////////////////////////////////////////////////////////////
// Internal API
//////////////////////////////////////////////////////////////////////////

  ** Return if the store can count without any per-rec inspection
  internal Bool canFastCount() { cx == null && search == null && limit == Int.maxVal }

  ** Max number of recs to read or Int.maxVal for unlimited
  internal Int limit { private set }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private static const Str breakVal := "break"
  private static const |Dict->Obj?| noopFunc := |Dict rec->Obj?| { null }

  private FolioContext? cx
  private Filter? search
  private Bool sort
  private Bool sorted
  private |Dict->Obj?| f
  private Dict[]? list
  private Obj? stop
  private Obj? errMsgObj
  private Ref[]? ids
  private Bool includeTrash
  private FolioRec?[]? byIdRecs
  private Err? err
}
