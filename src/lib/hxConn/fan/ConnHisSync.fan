//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Nov 2010  Brian Frank  Refactor out of obix
//    2 Jul 2012  Brian Frank  Redesign for conn framework
//   31 Jan 2022  Brian Frank  Redesign for Haxall
//

using haystack
using axon
using hx
using folio

**
** Implementation for the connSyncHis function
**
internal class ConnSyncHis
{

  new make(HxContext cx, HxConnPoint[] points, Obj? span)
  {
    this.cx     = cx
    this.task   = cx.rt.services.get(HxTaskService#, false)
    this.points = points
    this.num    = points.size
    this.span   = span
  }

  Dict[] run()
  {
    if (points.isEmpty) return Dict#.emptyList
    trace("Sync $num points...",  0)
    commitPending
    points.each |pt, i|
    {
      cx.heartbeat(Loc("connHisSync"))
      trace("Syncing $pt.dis.toCode (${i+1} of $num)...", i*100/num)
      r := sync(pt)
      if (r.has("err")) ++numErr; else ++numOk
      results.add(r)
    }
    trace("Complete: $numOk ok; $numErr errors", 100)
    return results
  }

  private Void commitPending()
  {
    points.each |pt|
    {
      pt.conn.send(HxMsg("hisPending", pt))
    }
  }

  private Dict sync(ConnPoint pt)
  {
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

  private Span toPointSpan(Dict rec, TimeZone tz)
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
      x = CoreLib.toSpan(this.span, tz.name)
    }
    if (x.tz != tz) throw ArgErr("Span tz $x.tz != Point tz $tz")
    return x
  }

  private Void trace(Str msg, Int progress)
  {
    if (task == null) return
    task.progress(Etc.makeDict2("msg", msg, "progress", Number(progress, Number.percent)))
  }

  private HxContext cx
  private ConnPoint[] points
  private HxTaskService? task
  private Obj? span
  private const Int num
  private Int numOk
  private Int numErr
  private Dict[] results := [,]
}