//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Jul 2012  Brian Frank  Creation
//   16 Jul 2021  Brian Frank  Refactor for Haxall
//

using concurrent
using xeto
using haystack
using obs
using folio
using hx

**
** HisCollectMgrActor wraps the HisCollectMgr
**
internal const class HisCollectMgrActor : PointMgrActor
{
  new make(PointExt ext) : super(ext, 100ms, HisCollectMgr#) {}

  Future writeAll() { send(HxMsg("writeAll")) }

  Future reset() { send(HxMsg("reset")) }
}

**************************************************************************
** HisCollectMgr
**************************************************************************

**
** HisCollectMgr manages the list of history collection points
**
internal class HisCollectMgr : PointMgr
{
  new make(PointExt ext) : super(ext)
  {
    // init top of the minute
    nextTopOfMin = DateTime.now(null).floor(1min) + 1min
  }

  override Obj? onReceive(HxMsg msg)
  {
    if (msg.id == "writeAll") return onWriteAll
    if (msg.id == "reset") return onReset
    return super.onReceive(msg)
  }

  override Obj? onObs(CommitObservation e)
  {
    try
    {
      // if trashing/removing point
      id := e.id
      if (e.isRemoved) { remove(id); return null }

      // map point to a HisCollectRec record and refresh
      rec := points[id]
      if (rec == null) rec = add(id, e.newRec)
      rec.onRefresh(this, e.newRec)

      // if the point is no longer configured for collection, remove it
      if (!rec.isHisCollect) remove(id)
    }
    catch (Err err) log.err("HisCollectMgr.onObs", err)
    return null
  }

  private HisCollectRec add(Ref id, Dict rec)
  {
    x := HisCollectRec(id, rec)
    points[id] = x
    if (watch != null) watch.add(id)
    return x
  }

  private Void remove(Ref id)
  {
    points.remove(id)
    if (watch != null) watch.remove(id)
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

    // short circuit if no points
    if (points.isEmpty) return

    // create/recreate watch if necessary
    if (watch == null || watch.isClosed)
      openWatch

    // read current state of all our points
    Dict?[]? recs := null
    try
      recs = watch.poll(0ms)
    catch (ShutdownErr e)
      return

    // at this point short circuit logging if not steady state;
    // however its important that we setup the watch **before** steady
    // state so that connectors have a chance to initiate their
    // polling/subscriptions so the data is ready to begin logging
    // once steady state is reached
    if (!ext.rt.isSteadyState) return

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

  private Obj? onReset()
  {
    log.info("hisCollectReset")
    oldId := watch?.id
    if (watch != null) watch.close
    openWatch
    return "Old: $oldId; New: $watch.id"
  }

  private Void openWatch()
  {
    watch = rt.watch.open("HisCollect")
    watch.lease = 1hr
    watch.addAll(points.keys)
  }

  private Ref:HisCollectRec points := [:]   // points tagged for hisCollect
  private Int refreshVer                    // folio.curVer of last refresh
  private Int refreshTicks                  // ticks for last refresh
  private DateTime nextTopOfMin             // next top-of-minute
  private HxWatch? watch                    // watch
}

