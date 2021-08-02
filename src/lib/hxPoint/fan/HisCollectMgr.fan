//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Jul 2012  Brian Frank  Creation
//   16 Jul 2021  Brian Frank  Refactor for Haxall
//

using concurrent
using haystack
using obs
using folio
using hx

**
** HisCollectMgrActor wraps the HisCollectMgr
**
internal const class HisCollectMgrActor : PointMgrActor
{
  new make(PointLib lib) : super(lib, 100ms, HisCollectMgr#) {}

  Future writeAll() { send(HxMsg("writeAll")) }
}

**************************************************************************
** HisCollectMgr
**************************************************************************

**
** HisCollectMgr manages the list of history collection points
**
internal class HisCollectMgr : PointMgr
{
  new make(PointLib lib) : super(lib)
  {
    // init top of the minute
    nextTopOfMin = DateTime.now(null).floor(1min) + 1min
  }

  override Obj? onReceive(HxMsg msg)
  {
    if (msg.id == "writeAll") return onWriteAll
    return super.onReceive(msg)
  }

  override Obj? onObs(CommitObservation e)
  {
    // if trashing/removing point
    id := e.id
    if (e.isRemoved) { points.remove(id); return null }

    // map point to a HisCollectRec record and refresh
    rec := points[id]
    if (rec == null) points[id] = rec = HisCollectRec(id, e.newRec)
    rec.onRefresh(this, e.newRec)

    // if the point is no longer configured for collection, remove it
    if (!rec.isHisCollect) points.remove(id)

    return null
  }

  override Void onCheck()
  {
    // check if we are top of the minute
    now := DateTime.now(null)
    topOfMin := false
    if (now >= nextTopOfMin)
    {
      nextTopOfMin = nextTopOfMin + 1min
      topOfMin = true
    }

    // short circuits
    if (ids.isEmpty) return
    if (!lib.rt.isSteadyState) return

    // read current state of all our points
    Dict?[]? recs := null
    try
      recs = watch.poll(0ms)
    catch (ShutdownErr e)
      return

    // iterate all our points
    recs.each |rec|
    {
      if (rec == null) return
      try
      {
        pt := points[rec.id]
        if (pt != null) pt.onCheck(this, rec, now, topOfMin)
      }
      catch (Err e) log.err("onCheck: $rec.dis", e)
    }
  }

  /* TODO
  private Void onRefresh()
  {
    this.ids = newPoints.keys.toImmutable

    // update watch if needed
    if (ids.size > 0)
    {
      // open watch if needed
      if (watch == null) watch = openWatch(proj)

      try
      {
        // add the ids (this also serves as poll renew)
        watch.addAll(ids)
      }
      catch (Err e)
      {
        // if something goes wrong, then re-open watch
        log.err("onRefresh Watch.addAll", e)
        try { watch.close } catch (Err e2) {}
        watch = openWatch(proj)
        watch.addAll(ids)
      }
    }
  }

  static Watch openWatch(HxRuntime rt)
  {
    watch := rt.watchOpen("HisCollect")
    watch.lease = 1hr
    return watch
    return Watch()
  }
  */

  override Str? onDetails(Ref id)
  {
    pt := points[id]
    if (pt == null) return null
    return pt.toDetails
  }

  private HisCollectRec get(Ref id)
  {
    points[id] ?: throw Err("Not hisCollect point: $id")
  }

  private Obj? onWriteAll()
  {
    num := 0
    points.each |pt|
    {
      if (pt.writePending(this)) num++
    }
    if (num > 0) log.info("hisCollectWriteAll [flushed $num points]")
    return Number(num)
  }

  private Ref:HisCollectRec points := [:]   // points tagged for hisCollect
  private Ref[] ids := Ref#.emptyList       // flattened list of ids for points
  private Int refreshVer                    // folio.curVer of last refresh
  private Int refreshTicks                  // ticks for last refresh
  private DateTime nextTopOfMin             // next top-of-minute
  private HxWatch? watch                    // watch
}

