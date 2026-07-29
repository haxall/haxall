//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jul 2026  Matthew Giannini  Creation
//

using concurrent
using xeto
using haystack

**
** FolioReadSink is how a Folio subclass emits raw recs back to the base
** class during a streaming read.  It owns all read option handling and
** all permission checking, so subclasses stream every rec matching their
** filter and let the sink decide what survives.
**
** `accept` and `prepCapacity` are the only members a subclass may use.
**
** A sink is single use; it carries the state of one read operation.
**
** A sink with a limit of zero must never be streamed into - `accept` would
** yield one rec before it could stop.  Folio short circuits that case so it
** never reaches a store, which keeps the check out of the per-rec path.
**
@NoDoc final class FolioReadSink
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Sink which routes accepted recs to the given callback
  new make(FolioContext? cx, Dict? opts, |Dict->Obj?| f)
  {
    o := opts ?: Etc.dict0
    this.cx     = cx
    this.limit  = (o.get("limit") as Number)?.toInt ?: Int.maxVal
    this.search = Filter.searchFromOpts(o)
    this.sort   = o.has("sort")
    this.f      = f
  }

  ** Sink which accumulates accepted recs into the given list
  new makeAccumulate(FolioContext? cx, Dict? opts, Dict[] acc)
    : this.make(cx, opts, |Dict rec->Obj?| { acc.add(rec); return null })
  {
    this.list = acc
  }

  ** Sink which only counts recs; backs the default doReadCount.  Applies
  ** no options and no permission checks - the base class only counts this
  ** way when neither is required.
  new makeCount()
  {
    this.limit = Int.maxVal
    this.f     = |Dict rec->Obj?| { return null }
  }

//////////////////////////////////////////////////////////////////////////
// Sink
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

  ** Offer one raw rec to the sink. Return non-null if the store should
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
// Internal API
//////////////////////////////////////////////////////////////////////////

  ** Return if the store can count without any per-rec inspection
  internal Bool canFastCount() { cx == null && search == null && limit == Int.maxVal }

  ** Max number of recs to read or Int.maxVal for unlimited
  internal Int limit { private set }

  ** Sort results by dis string
  internal Bool sort { private set }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private static const Str breakVal := "break"

  private FolioContext? cx
  private Filter? search
  private |Dict->Obj?| f
  private Dict[]? list
  private Obj? stop
}
