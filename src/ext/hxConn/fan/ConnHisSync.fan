//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Nov 2010  Brian Frank  Refactor out of obix
//    2 Jul 2012  Brian Frank  Redesign for conn framework
//   31 Jan 2022  Brian Frank  Redesign for Haxall
//    5 Sep 2022  Brian Frank  Break out core logic into AbstractSyncHis
//

using xeto
using haystack
using axon
using hx
using folio

**
** Base class to handle history syncs
**
@NoDoc abstract class AbstractSyncHis
{
  ** Constructor
  new make(Context cx, Obj[] points, Obj? span)
  {
    this.cxRef     = cx
    this.task      = cx.rt.services.get(HxTaskService#, false)
    this.num       = points.size
    this.pointsRef = points
    this.span      = span
  }

  ** Execute sync and return result dict for each point
  Dict[] run()
  {
    if (points.isEmpty) return Dict#.emptyList
    trace("Sync $num points...",  0)
    commitPending
    points.each |pt, i|
    {
      cx.heartbeat(Loc("connHisSync"))
      trace("Syncing " + dis(pt).toCode + " (${i+1} of $num)...", i*100/num)
      r := sync(pt)
      if (r.has("err")) ++numErr; else ++numOk
      results.add(r)
    }
    trace("Complete: $numOk ok; $numErr errors", 100)
    return results
  }

  ** Context for sync
  virtual Context cx() { cxRef }

  ** Points to sync
  virtual Obj[] points() { pointsRef }

  ** Display name for given point
  abstract Str dis(Obj pt)

  ** Hook to set point hisStatus to the pending state
  abstract Void commitPending()

  ** Sync the point and return result dict.
  ** The dict must have an 'err' tag if there was an error.
  abstract Dict sync(Obj point)

  ** Get span to use for given point
  Span toPointSpan(Dict rec, TimeZone tz)
  {
    Span? x
    if (this.span == null)
    {
      last := rec["hisEnd"] as DateTime
      now  := DateTime.now.toTimeZone(tz)
      if (last == null) last = now - 5day
      x = Span(last.plus(1ms), now+1hr)
    }
    else
    {
      // note that the span might have a timezone different than the
      // point's timezone, but we actually allow that in situations where
      // we must query the remote system in a different timezone
      x = CoreLib.toSpan(this.span, tz.name)
    }
    return x
  }

  ** Trace progress message
  private Void trace(Str msg, Int progress)
  {
    if (task == null) return
    task.progress(Etc.dict2("msg", msg, "progress", Number(progress, Number.percent)))
  }

  private Context cxRef
  private ConnPoint[] pointsRef
  private HxTaskService? task
  private Obj? span
  private const Int num
  private Int numOk
  private Int numErr
  private Dict[] results := [,]
}

**************************************************************************
** ConnSyncHis
**************************************************************************

**
** Implementation for the connSyncHis function
**
internal class ConnSyncHis : AbstractSyncHis
{
  new make(Context cx, ConnPoint[] points, Obj? span)
    : super(cx, points, span)
  {
  }

  override Str dis(Obj pt) { ((ConnPoint)pt).dis }

  override ConnPoint[] points() { super.points }

  override Void commitPending()
  {
    points.each |pt|
    {
      pt.conn.send(HxMsg("hisPending", pt))
    }
  }

  override Dict sync(Obj point)
  {
    pt := (ConnPoint)point

    // do fresh read of the point's record to get latest hisEnd
    // because ConnPoint.rec doesn't get transient changes
    rec := cx.db.readById(pt.id)

    // get span to use based on this point's timezone
    span := toPointSpan(rec, pt.tz)

    // route to connector actor; block forever here and rely on each
    // connector to not lock up its queue for too long; we check for
    // task cancellation using context heartbeat
    return pt.conn.send(HxMsg("syncHis", pt, span)).get(null)
  }

}

