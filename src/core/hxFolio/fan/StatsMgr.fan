//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 May 2016  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hxStore

**
** StatsMgr provides performance statistics for indexing and debugging
**
internal const class StatsMgr : HxFolioMgr
{

  new make(HxFolio folio) : super(folio)
  {
    diags = [
      FolioDiag("recs",         "Recs")                    |->Obj| { Number(folio.index.size) },
      FolioDiag("readCount",    "Read Count")              |->Obj| { Number(reads.count) },
      FolioDiag("readAvg",      "Read Avg")                |->Obj| { reads.avgTime },
      FolioDiag("pCommitCount", "Persistent Commit Count") |->Obj| { Number(commitsPersistent.count) },
      FolioDiag("pCommitAvg",   "Persistent Commit Avg")   |->Obj| { commitsPersistent.avgTime },
      FolioDiag("tCommitCount", "Transient Commit Count")  |->Obj| { Number(commitsTransient.count) },
      FolioDiag("tCommitAvg",   "Transient Commit Avg")    |->Obj| { commitsTransient.avgTime },
    ]
  }

  const StatsCountAndTicks commitsPersistent := StatsCountAndTicks()

  const StatsCountAndTicks commitsTransient := StatsCountAndTicks()

  const StatsCountAndTicks reads := StatsCountAndTicks()

  const StatsReadByPlan readsByPlan := StatsReadByPlan()

  const FolioDiag[] diags

  Void clear()
  {
    commitsPersistent.clear
    commitsTransient.clear
    reads.clear
    readsByPlan.clear
  }

  Grid debugSummary()
  {
    store := folio.store.blobs
    storeMeta := store.meta

    gb := GridBuilder()
    gb.addCol("dis").addCol("val")
    gb.addRow2("name",                         folio.dir.parent.name)
    gb.addRow2("dir",                          folio.dir.osPath)
    gb.addRow2("version",                      typeof.pod.version.toStr)
    gb.addRow2("idPrefix",                     folio.idPrefix)
    gb.addRow2("index.size",                   Number(folio.index.size))
    gb.addRow2("store.size",                   store.size.toLocale)
    gb.addRow2("store.ver",                    store.ver.toLocale)
    gb.addRow2("store.numPageFile",            store.pageFileSize.toLocale)
    gb.addRow2("store.blobMetaMax",            storeMeta.blobMetaMax.toLocale("B"))
    gb.addRow2("store.blobDataMax",            storeMeta.blobDataMax.toLocale("B"))
    gb.addRow2("store.hisPageSize",            Number(storeMeta.hisPageSize, Number.day))
    gb.addRow2("store.flushMode",              store.flushMode)
    gb.addRow2("store.unflushedCount",         Number(store.unflushedCount))
    gb.addRow2("store.gcFreezeCount",          Number(store.gcFreezeCount))
    gb.addRow2("store.backup",                 store.backup(null))
    gb.addRow2("reads.num",                    Number(reads.count))
    gb.addRow2("reads.totalTime",              reads.totalTime)
    gb.addRow2("reads.avgTime",                reads.avgTime)
    gb.addRow2("commits.persistent.num",       Number(commitsPersistent.count))
    gb.addRow2("commits.persistent.totalTime", commitsPersistent.totalTime)
    gb.addRow2("commits.persistent.avgTime",   commitsPersistent.avgTime)
    gb.addRow2("commits.transient.num",        Number(commitsTransient.count))
    gb.addRow2("commits.transient.totalTime",  commitsTransient.totalTime)
    gb.addRow2("commits.transient.avgTime",    commitsTransient.avgTime)
    return gb.toGrid
  }

  Grid debugReadsByPlan()
  {
    gb := GridBuilder()
    gb.addCol("plan").addCol("numReads").addCol("totalTime").addCol("avgTime")
    readsByPlan.each |stats, plan|
    {

      gb.addRow([plan, Number(stats.count), stats.totalTime, stats.avgTime])
    }
    return gb.sortrCol("numReads").toGrid
  }

}

**************************************************************************
** StatsCountAndTicks
**************************************************************************

internal const class StatsCountAndTicks
{
  Void add(Int ticks) { countRef.incrementAndGet; ticksRef.addAndGet(ticks) }

  Void clear() { countRef.val = ticksRef.val = 0 }

  override Str toStr() { "$count ($totalTime | $avgTime)"  }

  Str totalTime() { Duration(ticks).toLocale }

  Str avgTime() { count == 0 ? "-" : Duration(ticks/count).toLocale }

  Int count() { countRef.val }
  private const AtomicInt countRef := AtomicInt()

  Int ticks() { ticksRef.val }
  private const AtomicInt ticksRef := AtomicInt()
}

**************************************************************************
** StatsReadByTag
**************************************************************************

internal const class StatsReadByTag
{
  Void each(|Int count, Str tag| f)
  {
    map.each |AtomicInt v, Str t| { f(v.val, t) }
  }

  Int add(Str tag)
  {
    count := map.get(tag) as AtomicInt
    if (count == null) map.set(tag, count = AtomicInt())
    return count.incrementAndGet
  }

  Void clear() { map.clear }

  private const ConcurrentMap map := ConcurrentMap()
}

**************************************************************************
** StatsReadByPlan
**************************************************************************

internal const class StatsReadByPlan
{
  Void each(|StatsCountAndTicks stats, Str plan| f)
  {
    map.each(f)
  }

  Void add(Str plan, Int ticks)
  {
    stats := map.get(plan) as StatsCountAndTicks
    if (stats == null) map.set(plan, stats = StatsCountAndTicks())
    return stats.add(ticks)
  }

  Void clear() { map.clear }

  private const ConcurrentMap map := ConcurrentMap()
}

**************************************************************************
** FolioDiag
**************************************************************************

const class FolioDiag
{
  new make(Str name, Str dis, |->Obj| func)
  {
    this.name = name
    this.dis = dis
    this.func = func
  }
  const Str name
  const Str dis
  const |->Obj| func
  Obj? val() { func() }
}

