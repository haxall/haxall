//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jan 2022  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hx
using hxConn

const class ConnTestLib : ConnLib
{
}

class ConnTestDispatch : ConnDispatch
{
  new make(Obj arg) : super(arg) {}

  override Obj? onReceive(HxMsg msg)
  {
    switch (msg.id)
    {
      case "lastWrite": return lastWrites[msg.a]
      case "numWrites": return numWrites
      case "sleep":     Actor.sleep(msg.a); return null
      default:         return super.onReceive(msg)
    }
  }

  override Void onOpen()
  {
  }

  override Void onClose()
  {
  }

  override Dict onPing()
  {
    Etc.makeDict(["pingTime":DateTime.now])
  }

  override Void onWatch(ConnPoint[] points)
  {
    // log.info("onWatch $points.size")
    points.each |pt| { syncCur(pt) }
  }

  override Void onSyncCur(ConnPoint[] points)
  {
    // log.info("onSyncCur $points.size")
    points.each |pt| { syncCur(pt) }
  }

  private Void syncCur(ConnPoint pt)
  {
    val := pt.rec["testCurVal"] ?: Number((0..1000).random)
    // log.info("onSyncCur $pt.dis $val")

    if (pt.curAddr == "down")
    {
      pt.updateCurErr(DownErr("down"))
      return
    }

    if (pt.rec.has("testCurStatus"))
    {
      pt.updateCurErr(RemoteStatusErr(ConnStatus.fromStr(pt.rec->testCurStatus)))
      return
    }

    pt.updateCurOk(val)
  }

  override Void onWrite(ConnPoint point, ConnWriteInfo info)
  {
    // log.info("onWrite $point.dis | $info")

    val := info.val as Number
    level := info.level

    this.lastWrites[point.id] = "$val @ $level"
    this.numWrites++

    if (val == null || val >= Number.zero)
      point.updateWriteOk(info)
    else
      point.updateWriteErr(info, DownErr("neg value"))
  }

  override Void onHouseKeeping()
  {
    // log.info("onHouseKeeping")
  }

  Ref:Str lastWrites := [:]
  Int numWrites
}