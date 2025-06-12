//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Jul 2012  Brian Frank  Creation
//   14 Jul 2021  Brian Frank  Refactor for Haxall
//

using concurrent
using haystack
using folio
using obs
using hx

**
** WriteMgrActor wraps the WriteMgr
**
internal const class WriteMgrActor : PointMgrActor, HxPointWriteService
{
  new make(PointLib lib) : super(lib, 4sec, WriteMgr#) {}

  const WriteObservable observable := WriteObservable()

  override Grid array(Dict point) { arrayById(point.id) }

  Grid arrayById(Ref id) { send(HxMsg("array", id)).get(timeout) }

  override Future write(Dict point, Obj? val, Int level, Obj who, Dict? opts := null)
  {
    // level check
    if (level < 1 || level > 17) throw Err("Invalid level: $level")

    // who check
    if (who.toStr.isEmpty) throw Err("Must provide non-empty who Str")

    // sanity point tag checks
    if (point.missing("point")) throw Err("Missing point tag: $point.dis")
    if (point.missing("writable")) throw Err("Missing writable tag: $point.dis")
    kind := point["kind"] as Str ?: throw Err("Missing kind tag: $point.dis")

    // get actual value if wrapped as Dict { val, duration }
    valRef := val
    if (valRef is Dict) val = valRef->val

    // value check
    if (val != null)
    {
      switch (kind)
      {
        case "Number": if (val isnot Number) throw Err("Invalid Number val: $val.typeof")
        case "Bool":   if (val isnot Bool) throw Err("Invalid Bool val: $val.typeof")
        case "Str":    if (val isnot Str) throw Err("Invalid Str val: $val.typeof")
        default: throw Err("Invalid kind: $kind")
      }
    }

    // add/check unit if Number
    val = PointUtil.applyUnit(point, val, "write")

    return send(HxMsg("write", point.id, valRef, level, who, opts))
  }
}

**************************************************************************
** WriteMgr
**************************************************************************

**
** WriteMgr manages the list of writable points on background thread
**
internal class WriteMgr : PointMgr
{
  new make(PointLib lib) : super(lib) {}

  override Obj? onReceive(HxMsg msg)
  {
    if (msg.id === "write") return get(msg.a).write(this, msg.b, msg.c, msg.d, msg.e)
    if (msg.id === "array") return get(msg.a).toGrid
    return super.onReceive(msg)
  }

  override Void onCheck()
  {
    // check if we need to issue the first write observations
    if (needFirstFire && rt.isSteadyState)
    {
      needFirstFire = false
      fireFirstObservations
    }

    // iterate all the writable points to check for expired timed override
    now := Duration.now
    points.each |pt| { pt.check(this, now) }
  }

  private WriteRec get(Ref id)
  {
    points[id] ?: throw Err("Not writable point: $id.toZinc")
  }

  override Obj? onObs(CommitObservation e)
  {
    try
    {
      if (e.newRec.has("writable"))
      {
        pt := points[e.id]
        if (pt == null) points[e.id] = pt = WriteRec(this, e.id, e.newRec)
        pt.updateRec(e.newRec)
      }
      else
      {
        points.remove(e.id)
      }
    }
    catch (Err err) log.err("WriteMgr.onObs", err)
    return null
  }

  ** Called by WriteRec when the effective value+level has been updated
  internal Void sink(WriteRec writeRec, Obj? val, Number level, Obj? who)
  {
    // decide which tags to update and commit
    rec := writeRec.rec
    changes := sinkChanges(rec, val, level)
    rt.db.commitAsync(Diff(rec, changes, Diff.forceTransient))
  }

  private Dict sinkChanges(Dict rec, Obj? val, Number level)
  {
    if (val == null) val = Remove.val
    curTracks := rec.has("curTracksWrite")
    if (curTracks)
       return Etc.dict4(
                    "curVal",     val,
                    "curStatus",  "ok",
                    "writeVal",   val,
                    "writeLevel", level)
       return Etc.dict2(
                    "writeVal", val,
                    "writeLevel", level)
  }

  ** Called exactly once after we detect the system has entered steady state.
  ** This is when we fire off the first pointWrite observations.
  private Void fireFirstObservations()
  {
    points.each |pt|
    {
      fireObservation(pt, pt.lastVal, pt.lastLevel, "first", null, true, true)
    }
  }

  ** Called by WriteRec on all writes
  internal Void fireObservation(WriteRec writeRec, Obj? val, Number level, Obj? who, Dict? opts, Bool effectiveChange, Bool first)
  {
    // short circuit if observable has no subscriptions
    observable := lib.writeMgr.observable
    if (!observable.hasSubscriptions) return

    // we have two potential events; for normal subscribers we are sending an
    // event only on a new effective value+level.  But for the subscribers with
    // the 'obsAllWrites' flag we are firing event for each specific level change.
    // We lazily create these events in the loop below
    ts := DateTime.now
    rec := writeRec.rec
    WriteObservation? eventEff := null
    WriteObservation? eventAll := null

    // fire event to subscribed observers
    observable.subscriptions.each |WriteSubscription sub|
    {
      // short circuit if not an effective change and not subscribed to all changes
      if (!effectiveChange && !sub.isAllWrites) return

      // short circuit if subscription filter doesn't match
      if (!sub.include(rec)) return

      // fire event to this subscriber
      if (sub.isAllWrites)
      {
        // this subscriber has the 'obsAllWrites' flag, so we fire
        // event for the specific level which has been modified
        if (eventAll == null) eventAll = WriteObservation(observable, ts, writeRec.id, rec, val, level, who, opts, first)
        sub.send(eventAll)
      }
      else
      {
        // normal subscriber, so we fire an event for
        // the new effective level cached by lastVal, lastLevel
        if (eventEff == null) eventEff = WriteObservation(observable, ts, writeRec.id, rec, writeRec.lastVal, writeRec.lastLevel, who, opts, first)
        sub.send(eventEff)
      }
    }
  }

  override Str? onDetails(Ref id)
  {
    pt := points[id]
    if (pt == null) return null
    return pt.toDetails
  }

  private Bool needFirstFire := true
  private Ref:WriteRec points := [:]
}

