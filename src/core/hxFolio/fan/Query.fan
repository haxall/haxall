//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 May 2016  Brian Frank  Creation
//

using concurrent
using haystack
using xeto::Spec
using def
using folio

**
** Query manages the pipeline for filter based readAll/readCount
**
internal class Query : HaystackContext
{
  new make(HxFolio folio, Filter filter, Dict opts)
  {
    this.folio      = folio
    this.index      = folio.index
    this.filter     = filter
    this.opts       = QueryOpts(opts)
    this.startTicks = Duration.nowTicks
  }

  Dict[] collect(FolioContext? cx)
  {
    plan := makePlan
    acc := QueryCollect(cx, opts)
    plan.query(this, acc)
    updateStats(plan)
    list := acc.list
    if (opts.sort) list = Etc.sortDictsByDis(list)
    return list
  }

  Obj? eachWhile(FolioContext? cx, |Dict->Obj?| cb)
  {
    plan := makePlan
    acc := QueryEachWhile(cx, opts, cb)
    plan.query(this, acc)
    updateStats(plan)
    return acc.result
  }

  Int count(FolioContext? cx)
  {
    plan := makePlan
    acc := QueryCounter(cx, opts)
    plan.query(this, acc)
    updateStats(plan)
    return acc.count
  }

  QueryPlan makePlan()
  {
    if (!opts.skipTrash) return FullScanPlan()
    return doMakePlan(index, filter, false)
  }

  @NoDoc override Bool xetoIsSpec(Str specName, xeto::Dict rec)
  {
    ns := folio.hooks.xeto(false)
    if (ns == null) return false

    // cache the spec since it can be fairly expensive to lookup
    // and this method could be called 1000s of time in a filter loop
    spec := xetoIsSpecCache?.get(specName)
    if (spec == null)
    {
      if (xetoIsSpecCache == null) xetoIsSpecCache = Str:Spec[:]
      spec = specName.contains("::") ?
             ns.type(specName) :
             ns.unqualifiedType(specName)
      xetoIsSpecCache[specName] = spec
    }
    return ns.specOf(rec).isa(spec)
  }

  override Dict? deref(Ref id)
  {
    index.dict(id, false)
  }

  override once FilterInference inference()
  {
    ns := folio.hooks.ns(false)
    if (ns != null) return MFilterInference(ns)
    return FilterInference.nil
  }

  override Dict toDict() { Etc.emptyDict }

  static QueryPlan? doMakePlan(IndexMgr index, Filter filter, Bool inCompound)
  {
    // AND is cost based selection b/w LHS and RHS
    type := filter.type
    if (type === FilterType.and)
    {
      a := doMakePlan(index, filter.argA, true)
      b := doMakePlan(index, filter.argB, true)
      return a.cost <= b.cost ? a : b
    }

    // handle special case of id==XXXX
    if (type === FilterType.eq)
    {
      path := (FilterPath)filter.argA
      if (path.size == 1 && path.get(0) == "id")
        return ByIdPlan(filter.argB as Ref ?: Ref.nullRef, inCompound)
    }

    // Haxall does not support JIT tag indexing like full SkySpark,
    // so everything is always run as a full scan plan
    return FullScanPlan()
  }

  private Void updateStats(QueryPlan plan)
  {
    // update total count/ticks for reads
    ticks := Duration.nowTicks - startTicks
    stats := folio.stats
    stats.reads.add(ticks)

    // update stats for plan
    stats.readsByPlan.add(plan.debug, ticks)
  }

  const HxFolio folio
  const IndexMgr index
  const Filter filter
  const QueryOpts opts
  const Int startTicks
  private [Str:Spec]? xetoIsSpecCache
}

**************************************************************************
** QueryOpts
**************************************************************************

internal const class QueryOpts
{
  new make(Dict opts)
  {
    this.opts      = opts
    this.limit     = toLimit(opts)
    this.search    = toSearch(opts)
    this.skipTrash = opts.missing("trash")
    this.sort      = opts.has("sort")
  }

  new makeLimit(Int limit)
  {
    this.opts  = Etc.emptyDict
    this.limit = limit
  }

  private static Int toLimit(Dict opts)
  {
    optLimit := opts.get("limit", "not-found")
    if (optLimit is Number)
      return ((Number)optLimit).toInt
    else
      return Int.maxVal
  }

  private static Filter? toSearch(Dict opts)
  {
    search := opts["search"] as Str
    if (search == null) return null
    search = search.trimToNull
    if (search == null) return null
    return Filter.search(search)
  }

  const Dict opts
  const Int limit
  const Filter? search
  const Bool skipTrash
  const Bool sort
}

**************************************************************************
** QueryAcc
**************************************************************************

** QueryAcc is base class for accumulating query recs
internal abstract class QueryAcc
{
  ** Constructor
  new make(FolioContext? cx, QueryOpts opts)
  {
    this.cx     = cx
    this.limit  = opts.limit
    this.search = opts.search
  }

  ** Prepare internal capacity on accumulator list
  virtual Void prepCapacity(Int addingSize) {}

  ** Add record and return true to continue
  Bool add(Dict rec)
  {
    if (count >= limit) return false
    if (cx != null && !cx.canRead(rec)) return true
    if (search != null && !search.matches(rec, HaystackContext.nil)) return true
    count++
    if (!onAdd(rec)) return false
    return count < limit
  }

  ** Called when we have a record to accumulate; return true to continue
  abstract Bool onAdd(Dict rec)

  FolioContext? cx
  const Int limit
  Filter? search
  Int count
}

**************************************************************************
** QueryCollect
**************************************************************************

** QueryCollect accumulates to in-memory list
internal class QueryCollect : QueryAcc
{
  ** Constructor
  new make(FolioContext? cx, QueryOpts opts) : super(cx, opts) {}

  ** Prepare internal capacity on accumulator list
  override Void prepCapacity(Int addingSize)
  {
    total := list.size + addingSize
    if (total > limit) total = limit
    list.capacity = total
  }

  ** Called when we have a record to accumulate; return true to continue
  override Bool onAdd(Dict rec)
  {
    list.add(rec)
    return true
  }

  Dict[] list := Dict[,]
}

**************************************************************************
** QueryEachWhile
**************************************************************************

** QueryEachWhile accumulates to callback function
internal class QueryEachWhile : QueryAcc
{
  ** Constructor
  new make(FolioContext? cx, QueryOpts opts, |Dict->Obj?| cb) : super(cx, opts)
  {
    this.cb = cb
  }

  ** Called when we have a record to accumulate; return true to continue
  override Bool onAdd(Dict rec)
  {
    result = cb(rec)
    return result == null
  }

  |Dict->Obj?| cb
  Obj? result
}

**************************************************************************
** QueryCounter
**************************************************************************

** QueryCounter just iterates to increment base class counter
internal class QueryCounter : QueryAcc
{
  new make(FolioContext? cx, QueryOpts opts) : super(cx, opts) {}
  override Bool onAdd(Dict rec) { true }
}

**************************************************************************
** QueryPlan
**************************************************************************

** Abstract base class for query plans
internal abstract class QueryPlan
{
  abstract Str debug()

  abstract Int cost()

  abstract Void query(Query q, QueryAcc acc)
}

**************************************************************************
** EmptyPlan
**************************************************************************

** Empty plan is when we know there is zero matches
internal final class EmptyPlan : QueryPlan
{
  override Str debug() { "empty" }

  override Int cost() { 0 }

  override Void query(Query q, QueryAcc acc) {}
}

**************************************************************************
** ByIdPlan
**************************************************************************

** Optimization for "id == @xxx"
internal final class ByIdPlan : QueryPlan
{
  new make(Ref id, Bool inCompound) { this.id = id; this.inCompound = inCompound }

  const Ref id

  const Bool inCompound

  override Str debug() { "byId" }

  override Int cost() { 1 }

  override Void query(Query q, QueryAcc acc)
  {
    rec := q.index.dict(id, false)
    if (rec == null) return
    if (inCompound && !q.filter.matches(rec, q)) return
    acc.add(rec)
  }
}

**************************************************************************
** FullScanPlan
**************************************************************************

** Scan the entire index
internal final class FullScanPlan : QueryPlan
{
  override Str debug() { "fullScan" }

  override Int cost() { Int.maxVal }

  override Void query(Query q, QueryAcc acc)
  {
    q.index.byId.eachWhile |Rec rec->Obj?|
    {
      dict := rec.dict
      if (!q.filter.matches(dict, q)) return null
      if (rec.isTrash && q.opts.skipTrash) return null
      return acc.add(dict) ? null : "break"
    }
  }
}

