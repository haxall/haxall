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

**************************************************************************
** FolioReader
**************************************************************************

**
** FolioReader is the base class for one read operation against the
** database.  Subclasses determine how the results are produced and
** checked; the base class defines the API to return the results in
** different shapes.  A reader is single use; it carries the state of
** one read operation.
**
@NoDoc abstract class FolioReader
{
  ** Current context for permission checking resolved at construction
  protected FolioContext? cx := FolioContext.curFolio(false)

  ** Offer one raw rec to the reader; only filter readers accept streams.
  ** Return non-null if the store should stop streaming, in which case
  ** the store must return that value from its eachWhile hook.
  abstract Obj? accept(Dict rec)

  ** Hint that addingSize more recs are about to be offered so the
  ** accumulator can be pre-sized; no-op except FolioAccReader
  virtual Void prepCapacity(Int addingSize) {}

  ** Number of recs which passed every check
  virtual Int count() { throw UnsupportedErr("Count not available") }

  ** Get first result as rec wrapper
  virtual FolioRec? rec(Bool checked := true) { throw UnsupportedErr("FolioRecs not available") }

  ** Get results as rec wrappers
  virtual FolioRec?[] recs(Bool checked := true) { throw UnsupportedErr("FolioRecs not available") }

  ** Get first result as a Dict
  virtual Dict? dict(Bool checked := true) { throw UnsupportedErr("Dicts not available") }

  ** Get results as dicts
  virtual Dict?[] dicts(Bool checked := true) { throw UnsupportedErr("Dicts not available") }

  ** Get results as grid with support for standard read opts
  virtual Grid grid(Dict? opts, Bool checked)
  {
    Etc.makeDictsGrid(opts?.get("gridMeta"), dicts(checked))
  }
}

**************************************************************************
** FolioIdsReader
**************************************************************************

**
** FolioIdsReader checks and packages raw recs read by a list of ids.
** The constructor applies trash exclusion, permission checks, and error
** priority; the results match the ids by index with null for recs not
** found or not readable.
**
@NoDoc final class FolioIdsReader : FolioReader
{
  ** Apply trash exclusion and permission checks to one raw rec read by
  ** id.  This is the fast path for readRecById which allocates no reader.
  static FolioRec? checkRec(Ref id, FolioRec? rec, Bool checked)
  {
    cx := FolioContext.curFolio(false)
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

  ** Check the raw recs read for the given ids; recs match ids by index
  new make(Ref[] ids, FolioRec?[] recs, Bool includeTrash)
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
    this.checkedRecs = recs
  }

  override Obj? accept(Dict rec) { throw UnsupportedErr("Not a filter reader") }

  override FolioRec? rec(Bool checked := true)
  {
    rec := checkedRecs.getSafe(0)
    if (rec != null) return rec
    if (checked) throw err ?: UnknownRecErr("")
    return null
  }

  override FolioRec?[] recs(Bool checked := true)
  {
    if (checked && err != null) throw err
    return checkedRecs
  }

  override Dict? dict(Bool checked := true)
  {
    dict := checkedRecs.getSafe(0)?.dict
    if (dict != null) return dict
    if (checked) throw err ?: UnknownRecErr("")
    return null
  }

  override Dict?[] dicts(Bool checked := true)
  {
    if (checked && err != null) throw err
    return checkedRecs.map |rec->Dict?| { rec?.dict }
  }

  private FolioRec?[] checkedRecs
  private Err? err
}

**************************************************************************
** FolioFilterReader
**************************************************************************

**
** FolioFilterReader is the base class for filter based reads.  It owns
** the per-rec checks shared by every filter read: permissions, search
** option, and limit option.  The store streams every raw rec matching
** the filter into `accept` and the `hit` hook determines what the
** subclass does with recs which pass every check.
**
** A reader with a limit of zero must never be streamed into - `accept`
** would yield one rec before it could stop.  Folio short circuits that
** case so it never reaches a store, which keeps the check out of the
** per-rec path.
**
@NoDoc abstract class FolioFilterReader : FolioReader
{
  new make(Filter filter, Dict? opts)
  {
    o := opts ?: Etc.dict0
    this.filter = filter
    this.limit  = (o.get("limit") as Number)?.toInt ?: Int.maxVal
    this.search = Filter.searchFromOpts(o)
  }

  ** Filter for this read operation
  const Filter filter

  ** Max number of recs to read or Int.maxVal for unlimited
  const Int limit

  ** Search option
  const Filter? search

  ** Number of recs which passed every check
  override Int count { private set }

  ** Offer one raw rec to the reader. Return non-null if the store should
  ** stop streaming, in which case the store must return that value from
  ** its eachWhile hook.
  override Obj? accept(Dict rec)
  {
    // stay stopped even if the store ignored a previous stop
    if (stop != null) return stop

    // skip recs we cannot read or which fail the search filter
    if (cx != null && !cx.canRead(rec)) return null
    if (search != null && !search.matches(rec, HaystackContext.nil)) return null

    // rec passed every check, so it counts against the limit
    ++count
    r := hit(rec)
    if (r != null) { stop = r; return r }
    if (count >= limit) { stop = breakVal; return breakVal }
    return null
  }

  ** Hook to process a rec which passed checks; return non-null to break
  protected abstract Obj? hit(Dict rec)

  private static const Str breakVal := "break"
  private Obj? stop
}

**************************************************************************
** FolioCountReader
**************************************************************************

**
** FolioCountReader counts the recs matching a filter
**
@NoDoc final class FolioCountReader : FolioFilterReader
{
  new make(Filter filter, Dict? opts) : super(filter, opts) {}

  ** Return if the store can count without any per-rec inspection
  internal Bool canFastCount() { cx == null && search == null && limit == Int.maxVal }

  protected override Obj? hit(Dict rec) { null }
}

**************************************************************************
** FolioAccReader
**************************************************************************

**
** FolioAccReader accumulates the recs matching a filter
**
@NoDoc final class FolioAccReader : FolioFilterReader
{
  new make(Filter filter, Dict? opts) : super(filter, opts)
  {
    this.sort = opts != null && opts.has("sort")
  }

  override Void prepCapacity(Int addingSize)
  {
    total := acc.size + addingSize
    if (total > limit) total = limit
    acc.capacity = total
  }

  protected override Obj? hit(Dict rec)
  {
    acc.add(rec)
    return null
  }

  override Dict?[] dicts(Bool checked := true)
  {
    if (sort) return Etc.sortDictsByDis(acc)
    return acc
  }

  override Dict? dict(Bool checked := true)
  {
    dict := acc.getSafe(0)
    if (dict != null) return dict
    if (checked) throw UnknownRecErr(filter.toStr)
    return null
  }

  private const Bool sort
  private Dict[] acc := [,]
}

**************************************************************************
** FolioEachReader
**************************************************************************

**
** FolioEachReader streams the recs matching a filter to a callback
**
@NoDoc final class FolioEachReader : FolioFilterReader
{
  new make(Filter filter, Dict? opts, |Dict->Obj?| f) : super(filter, opts)
  {
    this.f = f
  }

  ** Non-null result returned by the callback which stopped the stream
  Obj? result { private set }

  protected override Obj? hit(Dict rec)
  {
    r := f(rec)
    if (r != null) result = r
    return r
  }

  private |Dict->Obj?| f
}

