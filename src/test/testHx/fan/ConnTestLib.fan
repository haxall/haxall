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

  override Void onOpen()
  {
  }

  override Void onClose()
  {
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

  override Dict onPing()
  {
    Etc.makeDict(["pingTime":DateTime.now])
  }
}