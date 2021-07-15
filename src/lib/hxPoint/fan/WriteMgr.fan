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
internal const class WriteMgrActor : PointMgrActor
{
  new make(PointLib lib) : super(lib, 4sec, WriteMgr#) {}

  const WriteObservable observable := WriteObservable()

  Grid array(Ref id) { send(HxMsg("array", id)).get(timeout) }

  Future write(Dict point, Obj? val, Int level, Obj who)
  {
    // level check
    if (level < 1 || level > 17) throw Err("Invalid level: $level")

    // who check
    if (who.toStr.isEmpty) throw Err("Must provide non-empty who Str")

    // sanity point tag checks
    if (point.missing("point")) throw Err("Missing point tag: $point.dis")
    if (point.missing("writable")) throw Err("Missing writable tag: $point.dis")
    kind := point["kind"] as Str ?: throw Err("Missing kind tag: $point.dis")

    // get actual value (if wrapped a TimedOverride)
    valRef := val
    if (valRef is TimedOverride) val = ((TimedOverride)val).val

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
    val = applyUnit(point, val, "write")

    return send(HxMsg("write", point.id, valRef, level, who))
  }

  private static Obj? applyUnit(Dict point, Obj? val, Str action)
  {
    // if not number, nothing to do
    num := val as Number
    if (num == null) return val

    // safely get unit from point's unit tag
    unit := Number.loadUnit(point["unit"] as Str ?: "", false)
    if (unit == null) return val

    // if number provided is unitless, then use point's unit
    if (num.unit == null) return Number(num.toFloat, unit)

    // sanity check mismatched units
    if (num.unit !== unit) throw Err("point unit != $action unit: $unit != $num.unit")
    return val
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
    if (msg.id === "write") return get(msg.a).write(this, msg.b, msg.c, msg.d)
    if (msg.id === "array") return get(msg.a).toGrid
    if (msg.id === "obs")   return onObs(msg.a)
    return super.onReceive(msg)
  }

  override Void onCheck()
  {
    // iterate all the writable points to check for expired timed override
    now := Duration.now
    points.each |pt| { pt.check(this, now) }
  }

  private WriteRec get(Ref id)
  {
    points[id] ?: throw Err("Not writable point: $id.toZinc")
  }

  private Obj? onObs(CommitObservation e)
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
    return null
  }

  ** Called by WriteRec when the effective value+level has been updated
  internal Void sink(WriteRec writeRec, Obj? val, Number level, Obj? who)
  {
    // decide which tags to update and commit
    rec := writeRec.rec
    changes := sinkChanges(rec, val, level)
    rt.db.commitAsync(Diff(rec, changes, Diff.forceTransient))

    // short circuit if observable has no subscriptions
    observable := lib.writeMgr.observable
    if (!observable.hasSubscriptions) return

    // fire event to subscribed observers
    ts := DateTime.now
    stdEvent := WriteObservation(observable, ts, writeRec.id, rec, val, level, who, null)
    WriteObservation? arrayEvent := null
    observable.subscriptions.each |WriteSubscription sub|
    {
      // short circuit if subscription filter doesn't match
      if (!sub.include(rec)) return

      // lazily create array only when needed and fire appropriate event instance
      if (sub.includeArray)
      {
        if (arrayEvent == null) arrayEvent = WriteObservation(observable, ts, writeRec.id, rec, val, level, who, writeRec.toGrid)
        sub.send(arrayEvent)
      }
      else
      {
        sub.send(stdEvent)
      }
    }
  }

  private Dict sinkChanges(Dict rec, Obj? val, Number level)
  {
    if (val == null) val = Remove.val
    curTracks := rec.has("curTracksWrite")
    if (curTracks)
       return Etc.makeDict4(
                    "curVal",     val,
                    "curStatus",  "ok",
                    "writeVal",   val,
                    "writeLevel", level)
       return Etc.makeDict2(
                    "writeVal", val,
                    "writeLevel", level)
  }

  override Str? onDetails(Ref id)
  {
    pt := points[id]
    if (pt == null) return null
    return pt.toDetails
  }

  private Ref:WriteRec points := [:]
}