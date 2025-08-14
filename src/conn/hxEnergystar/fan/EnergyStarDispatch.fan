//
// Copyright (c) 2013, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jun 2013  Brian Frank  Creation
//   05 Aug 2025  Matthew Giannini  Refactor for hxConn
//

using xeto
using haystack
using hxConn

class EnergyStarDispatch : ConnDispatch
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(Obj arg) : super(arg) {}

  protected EnergyStarExt energyStar() { ext }

  private EnergyStarClient? client

//////////////////////////////////////////////////////////////////////////
// Open/Close/Ping
//////////////////////////////////////////////////////////////////////////

  override Void onOpen()
  {
    this.client = EnergyStarClient(proj, rec)
  }

  override Void onClose()
  {
    this.client = null
  }

  override Dict onPing()
  {
    // ping account info
    client.ping
  }

//////////////////////////////////////////////////////////////////////////
// Points
//////////////////////////////////////////////////////////////////////////

  override Obj? onSyncHis(ConnPoint point, Span span)
  {
    try
    {
      items := HisItem[,]
      meterId := EnergyStarFuncs.pointToMeterId(proj, point.rec)
      tz := TimeZone.fromStr(point.rec->tz)
      client.readUsage(meterId) |id, startDate, endDate, usage|
      {
        // map start/end date to timestamp
        // if (startDate != endDate) throw Err("startDate != endDate: $startDate != $endDate")
        ts := startDate.toDateTime(Time.defVal, tz)

        // if after range still then keep reading
        if (ts > span.end) return true

        // if we have gone before range we are done
        if (ts < span.start) return false

        // this is within our range
        items.add(HisItem(ts, usage))
        return true
      }
      return point.updateHisOk(items, span)
    }
    catch (Err e)
    {
      return point.updateHisErr(e)
    }
  }

}

