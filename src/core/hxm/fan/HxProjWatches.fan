//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Mar 2016  Brian Frank  Creation
//  22 Jul 2021  Brian Frank  Port to Haxall
//

using concurrent
using xeto
using haystack
using folio
using hx

**
** Implementation for ProjWatches
**
internal const class HxProjWatches : ProjWatches
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(HxProj proj)
  {
    this.proj = proj
    this.byId = ConcurrentMap()
  }

//////////////////////////////////////////////////////////////////////////
// Lookup Tables
//////////////////////////////////////////////////////////////////////////

  const HxProj proj          // parent project
  const ConcurrentMap byId   // Str:HxWatch

  override HxWatch[] list()
  {
    byId.vals(HxWatch#)
  }

  override HxWatch[] listOn(Ref id)
  {
    acc := HxWatch[,]
    byId.each |HxWatch w|
    {
      if (w.refs.get(id) != null) acc.add(w)
    }
    return acc
  }

  override HxWatch? get(Str id, Bool checked := true)
  {
    w := byId.get(id)
    if (w != null) return w
    if (checked) throw UnknownWatchErr(id)
    return null
  }

  override HxWatch open(Str dis)
  {
    w := HxWatch(this, dis)
    byId.add(w.id, w)
    return w
  }

  override Bool isWatched(Ref id)
  {
//    rec := proj.db.rec(id, false)
//    return rec != null && rec.numWatches.val > 0
throw Err("TODO")
  }

  override Void checkExpires()
  {
    toExpire := HxWatch[,]
    now := Duration.now
    byId.each |HxWatch w|
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
** HxWatch
**************************************************************************

internal const class HxWatch : Watch
{
  new make(HxProjWatches service, Str dis)
  {
    this.service = service
    this.dis     = dis
    this.id      = "w-"+ Ref.gen.id
    this.created = Duration.nowTicks
    this.refs    = ConcurrentMap()
  }

  const HxProjWatches service
  const override Str dis
  const override Str id
  const Int created
  const ConcurrentMap refs  // Ref:HxWatchRef

  override HxProj proj() { service.proj }

  override Ref[] list()
  {
    checkOpen
    return refs.keys(Ref#)
  }

  override Bool isEmpty() { refs.isEmpty }

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
    refs.each |HxWatchRef r|
    {
      if (!r.ok) return
/*
      rec := service.db.rec(r.id, false)
      if (rec != null && rec.ticks > t.ticks)
      {
        acc.add(rec.dict)
      }
*/
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
    Dict[]? firstRecs
    ids.each |id|
    {
      // if already added, skip it
      if (refs[id] != null) return

      // lookup rec and verify ok = found and canRead
/*
      rec := service.db.rec(id, false)
      ok := rec != null && (cx == null || cx.canRead(rec.dict))
      refs[id] = HxWatchRef(id, ok)

      // if ok, then see if this is a first watch
      if (ok)
      {
        firstWatch := rec.numWatches.getAndIncrement == 0
        if (firstWatch)
        {
          if (firstRecs == null) firstRecs = Dict[,]
          firstRecs.add(rec.dict)
        }
      }
*/
    }
// TODO
//obs := (HxObsService)proj.obs
//    if (firstRecs != null) obs.watches.fireWatch(firstRecs)
  }

  override Void removeAll(Ref[] ids)
  {
    renew
    Dict[]? lastRecs
    ids.each |id|
    {
/* TODO
      wr := refs.remove(id) as HxWatchRef
      if (wr == null || !wr.ok) return
      rec := service.db.rec(id, false)
      if (rec != null)
      {
        lastWatch := rec.numWatches.decrementAndGet == 0
        if (lastWatch)
        {
          if (lastRecs == null) lastRecs = Dict[,]
          lastRecs.add(rec.dict)
        }
      }
*/
    }
// TODO
//obs := (HxObsService)rt.obs
//    if (lastRecs != null) obs.watches.fireUnwatch(lastRecs)
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
    service.byId.remove(id)
  }
}

**************************************************************************
** HxWatchRef
**************************************************************************

internal const class HxWatchRef
{
  new make(Ref id, Bool ok) { this.id = id; this.ok = ok }
  const Ref id
  const Bool ok
}

