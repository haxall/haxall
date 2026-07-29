//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 May 2016  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using def
using folio

**
** Query manages the pipeline for filter based readAll/readCount
**
internal class Query : HaystackContext
{
  new make(HxFolio folio, Filter filter)
  {
    this.folio      = folio
    this.index      = folio.index
    this.filter     = filter
    this.startTicks = Duration.nowTicks
  }

  ** Stream matching recs to the sink; return the sink's stop value
  Obj? eachWhile(FolioReadSink sink)
  {
    plan := makePlan
    stop := plan.query(this, sink)
    updateStats(plan)
    return stop
  }

  ** Configure this query to match only records in the trash
  This onlyTrash() { trashOnly = true; return this }

  QueryPlan makePlan()
  {
    // trash recs are excluded from the tag indexes, so always full scan
    if (trashOnly) return FullScanPlan()
    return doMakePlan(index, filter, false)
  }

  @NoDoc override Bool xetoIsSpec(Str specName, xeto::Dict rec)
  {
    ns := folio.hooks.ns(false)
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
    recSpec := ns.specOf(rec, false)
    if (recSpec == null) return false
    return recSpec.isa(spec)
  }

  override Dict? deref(Ref id)
  {
    index.dict(id, false)
  }

  override once FilterInference inference()
  {
    ns := folio.hooks.defs(false)
    if (ns != null) return MFilterInference(ns)
    return FilterInference.nil
  }

  override Dict toDict() { Etc.dict0 }

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
  const Int startTicks
  Bool trashOnly { private set }
  private [Str:Spec]? xetoIsSpecCache
}

**************************************************************************
** QueryPlan
**************************************************************************

** Abstract base class for query plans
internal abstract class QueryPlan
{
  abstract Str debug()

  abstract Int cost()

  ** Stream matching recs to the sink; return the sink's stop value
  abstract Obj? query(Query q, FolioReadSink sink)
}

**************************************************************************
** EmptyPlan
**************************************************************************

** Empty plan is when we know there is zero matches
internal final class EmptyPlan : QueryPlan
{
  override Str debug() { "empty" }

  override Int cost() { 0 }

  override Obj? query(Query q, FolioReadSink sink) { null }
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

  override Obj? query(Query q, FolioReadSink sink)
  {
    // this plan is never used for trash queries, so always skip trash
    rec := q.index.rec(id, false)
    if (rec == null || rec.isTrash) return null
    dict := rec.dict
    if (inCompound && !q.filter.matches(dict, q)) return null
    return sink.accept(dict)
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

  override Obj? query(Query q, FolioReadSink sink)
  {
    q.index.byId.eachWhile |Rec rec->Obj?|
    {
      dict := rec.dict
      if (!q.filter.matches(dict, q)) return null
      if (rec.isTrash != q.trashOnly) return null
      return sink.accept(dict)
    }
  }
}

