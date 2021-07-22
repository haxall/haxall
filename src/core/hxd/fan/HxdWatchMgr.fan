//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Mar 2016  Brian Frank  Creation
//  22 Jul 2021  Brian Frank  Port to Haxall
//

using concurrent
using haystack
using folio
using hx
using hxFolio

**
** HxdWatchMgr manages the watches in the daemon runtime
**
internal const class HxdWatchMgr : HxRuntimeWatches
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(HxdRuntime rt)
  {
    this.rt   = rt
    this.db   = rt.db
    this.byId = ConcurrentMap()
  }

//////////////////////////////////////////////////////////////////////////
// Lookup Tables
//////////////////////////////////////////////////////////////////////////

  const HxdRuntime rt       // parent runtime
  const HxFolio db          // requires access to Rec
  const ConcurrentMap byId  // Str:HxdWatch

  override HxdWatch[] list()
  {
    byId.vals(HxdWatch#)
  }

  override HxdWatch[] listOn(Ref id)
  {
    acc := HxdWatch[,]
    byId.each |HxdWatch w|
    {
      if (w.refs.get(id) != null) acc.add(w)
    }
    return acc
  }

  override HxdWatch? get(Str id, Bool checked := true)
  {
    w := byId.get(id)
    if (w != null) return w
    if (checked) throw UnknownWatchErr(id)
    return null
  }

  override HxdWatch open(Str dis)
  {
    w := HxdWatch(this, dis)
    byId.add(w.id, w)
    return w
  }

  override Bool isWatched(Ref id)
  {
    rec := db.rec(id, false)
    return rec != null && rec.numWatches.val > 0
  }

  override Void checkExpires()
  {
    toExpire := HxdWatch[,]
    now := Duration.now
    byId.each |HxdWatch w|
    {
      if (w.lastRenew + w.lease < now) toExpire.add(w)
    }
    toExpire.each |w| { w.close }
  }

  override Grid debugGrid()
  {
    gb := GridBuilder()
    gb.addCol("id").addCol("dis").addCol("age").addCol("lastRenew").addCol("lastPoll").addCol("size")
    watches := list
    watches.sort |a, b| { a.created <=> b.created }
    watches.each |watch|
    {
      gb.addRow([
        Ref(watch.id),
        watch.dis,
        Etc.debugDur(watch.created),
        Etc.debugDur(watch.lastRenew.ticks),
        Etc.debugDur(watch.lastPoll.ticks),
        Number(watch.refs.size)
      ])
    }
    return gb.toGrid
  }
}

**************************************************************************
** HxdWatch
**************************************************************************

internal const class HxdWatch : HxWatch
{
  new make(HxdWatchMgr mgr, Str dis)
  {
    this.mgr     = mgr
    this.dis     = dis
    this.id      = "w-"+ Ref.gen.id
    this.created = Duration.nowTicks
    this.refs    = ConcurrentMap()
  }

  const HxdWatchMgr mgr
  const override Str dis
  const override Str id
  const Int created
  const ConcurrentMap refs  // Ref:HxdWatchRef

  override HxRuntime rt() { mgr.rt }

  override Ref[] list()
  {
    checkOpen
    return refs.keys(Ref#)
  }

  override Duration lastPoll() { lastPollRef.val }
  private const AtomicRef lastPollRef := AtomicRef(Duration.defVal)

  override Duration lastRenew() { lastRenewRef.val }
  private const AtomicRef lastRenewRef := AtomicRef(Duration.now)

  override Duration lease
  {
    get { leaseRef.val }
    set { leaseRef.val = it.min(1hr) }
  }
  private const AtomicRef leaseRef := AtomicRef(1min)

  override Dict[] poll(Duration t := lastPoll)
  {
    checkOpen
    now := Duration.now
    lastPollRef.val = now
    lastRenewRef.val = now

    acc := Dict[,]
    refs.each |HxdWatchRef r|
    {
      if (!r.ok) return
      rec := mgr.db.rec(r.id, false)
      if (rec != null && rec.ticks > t.ticks)
      {
        acc.add(rec.dict)
      }
    }
    return acc
  }

  override Void renew()
  {
    checkOpen
    lastRenewRef.val = Duration.now
  }

  override Void addAll(Ref[] ids)
  {
    renew
    cx := FolioContext.curFolio(false)
    Rec[]? firstRecs
    ids.each |id|
    {
      // if already added, skip it
      if (refs[id] != null) return

      // lookup rec and verify ok = found and canRead
      rec := mgr.db.rec(id, false)
      ok := rec != null && (cx == null || cx.canRead(rec.dict))
      refs[id] = HxdWatchRef(id, ok)

      // if ok, then see if this is a first watch
      if (ok)
      {
        firstWatch := rec.numWatches.getAndIncrement == 0
        if (firstWatch)
        {
          if (firstRecs == null) firstRecs = Rec[,]
          firstRecs.add(rec)
        }
      }
    }
// TODO
//    if (firstRecs != null) proj.concernMgr.watch(firstRecs)
  }

  override Void removeAll(Ref[] ids)
  {
    renew
    Rec[]? lastRecs
    ids.each |id|
    {
      wr := refs.remove(id) as HxdWatchRef
      if (wr == null || !wr.ok) return
      rec := mgr.db.rec(id, false)
      if (rec != null)
      {
        lastWatch := rec.numWatches.decrementAndGet == 0
        if (lastWatch)
        {
          if (lastRecs == null) lastRecs = Rec[,]
          lastRecs.add(rec)
        }
      }
    }
// TODO
//    if (lastRecs != null) proj.concernMgr.unwatch(lastRecs)
  }

  override Void set(Ref[] ids)
  {
    toAdd := Ref[,]
    toRemove := Ref:Ref[:]
    refs.each |Obj val, Ref id| { toRemove[id] = id }

    ids.each |id|
    {
      if (refs[id] != null)
        toRemove.remove(id)  // keep it (don't remove)
      else
        toAdd.add(id) // add
    }

    addAll(toAdd)
    removeAll(toRemove.vals)
  }

  override Bool isClosed() { closedRef.val }
  private const AtomicBool closedRef := AtomicBool(false)

  private Void checkOpen()
  {
    if (isClosed) throw WatchClosedErr(id)
  }

  override Void close()
  {
    removeAll(list)
    closedRef.val = true
    mgr.byId.remove(id)
  }
}

**************************************************************************
** HxdWatchRef
**************************************************************************

internal const class HxdWatchRef
{
  new make(Ref id, Bool ok) { this.id = id; this.ok = ok }
  const Ref id
  const Bool ok
}

