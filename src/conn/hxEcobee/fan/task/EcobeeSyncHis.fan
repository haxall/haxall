//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Feb 2022  Matthew Giannini  Creation
//

using haystack
using hxConn

internal class EcobeeSyncHis : EcobeeConnTask
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(EcobeeDispatch dispatch, ConnPoint point, Span span)
    : super(dispatch)
  {
    this.point   = point
    this.span    = span
    this.utcSpan = span.toTimeZone(TimeZone.utc)
  }

  private const ConnPoint point
  private const Span span
  private const Span utcSpan

//////////////////////////////////////////////////////////////////////////
// Conn Task
//////////////////////////////////////////////////////////////////////////

  override Obj? run()
  {
    try
    {
      propId := toHisId(point)

      // TODO: only support runtime report data right now
      if (!propId.isRuntime) throw FaultErr("Unsupported his property: $propId")

      // ecobee requires the request dates to be in UTC, but the resulting
      // data is in thermostat timezone!
      req := RuntimeReportReq {
        it.selection = EcobeeSelection(propId.thermostatId)
        it.startDate = utcSpan.start.date
        it.endDate   = utcSpan.end.date
        it.columns   = propId.propSpecs.last.prop
      }
      resp   := client.report.runtime(req)
      report := resp.reportList.first

      items  := HisItem[,]
      HisItem? prevItem := null
      report.rowList.each |csv|
      {
        vals := csv.split(',')
        date := Date.fromStr(vals[0])
        time := Time.fromStr(vals[1])
        ts   := date.toDateTime(time, point.tz)

        if (!span.contains(ts)) return

        Obj? val := vals.getSafe(2)
        if (point.kind.isNumber) val = Number.fromStr(val, false)

        items.add(HisItem(ts, val))
        prevItem = items.last
      }
      return point.updateHisOk(items, span)
    }
    catch (Err err)
    {
      return point.updateHisErr(err)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  // ** Get the first report as a his grid
  // private Grid toHisGrid(RuntimeReportResp resp)
  // {
  //   report := resp.reportList.first
  //   gb := GridBuilder()
  //   gb.addCol("ts").addColNames(resp.columns.split(','))
  //   report.rowList.each |csv|
  //   {
  //     vals := csv.split(',')
  //     date := Date.fromStr(vals[0])
  //     time := Time.fromStr(vals[1])
  //     ts   := date.toDateTime(time, point.tz)
  //     row  := Obj?[ts]
  //     vals[2..-1].each |val|
  //     {
  //       row.add(Number.fromStr(val, false) ?: val.toStr)
  //     }
  //     gb.addRow(row)
  //   }
  //   return gb.toGrid
  // }
}