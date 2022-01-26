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
      case "lastWrite": return lastWrite
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

  override Void onSyncCur(ConnPoint[] points)
  {
    points.each |pt, i|
    {
      if (pt.curAddr == "down")
        pt.updateCurErr(DownErr("down"))
      else
        pt.updateCurOk(Number(i))
    }
  }

  override Void onWrite(ConnPoint point, ConnWriteInfo info)
  {
    val := info.val as Number
    level := info.level

    this.lastWrite = "$val @ $level"
    this.numWrites++

    if (val == null || val >= Number.zero)
      point.updateWriteOk(info)
    else
      point.updateWriteErr(info, DownErr("neg value"))
  }

  Str? lastWrite
  Int numWrites
}