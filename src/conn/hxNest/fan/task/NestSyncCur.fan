//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2022  Matthew Giannini  Creation
//

using haystack
using hxConn

**
** Utility to synchronize the curVal for a list of points
**
internal class NestSyncCur : NestConnTask
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(NestDispatch dispatch, ConnPoint[] points) : super(dispatch)
  {
    this.points = points
  }

  private ConnPoint[] points
  private [Str:ConnPoint[]] byDevice := [:]

//////////////////////////////////////////////////////////////////////////
// Sync
//////////////////////////////////////////////////////////////////////////

  override Obj? run()
  {
    init
    openPin
    try
    {
      byDevice.each |points, deviceId|
      {
        syncDevice(deviceId, points)
      }
      return points
    }
    finally
    {
      closePin
    }
  }

  private Void init()
  {
    // map the points by device so we can minimize the number of API calls
    // we need to make
    points.each |point|
    {
      traitRef := toCurId(point)
      byDevice.getOrAdd(traitRef.deviceId) { ConnPoint[,] }.add(point)
    }
  }

  private Void syncDevice(Str deviceId, ConnPoint[] points)
  {
    try
    {
      device := client.devices.get(deviceId)
      points.each |pt| { updateCur(device, pt) }
    }
    catch (Err err)
    {
      points.each |pt| { pt.updateCurErr(err) }
    }
  }

  private Void updateCur(NestDevice device, ConnPoint point)
  {
    traitRef := toCurId(point)
    try
    {
      point.updateCurOk(NestUtil.getTraitVal(device, traitRef))
    }
    catch (Err err)
    {
      point.updateCurErr(err)
    }
  }
}