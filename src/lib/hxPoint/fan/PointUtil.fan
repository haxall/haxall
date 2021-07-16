//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jul 2021  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hx

**
** Point utilties
**
class PointUtil
{

  ** Is given point tagged for history collection
  static Bool isHisCollect(Dict pt)
  {
    pt.has("hisCollectInterval") || pt.has("hisCollectCov")
  }

  ** Default or check numeric point unit
  static Obj? applyUnit(Dict pt, Obj? val, Str action)
  {
    // if not number, nothing to do
    num := val as Number
    if (num == null) return val

    // safely get unit from point's unit tag
    unit := Number.loadUnit(pt["unit"] as Str ?: "", false)
    if (unit == null) return val

    // if number provided is unitless, then use point's unit
    if (num.unit == null) return Number(num.toFloat, unit)

    // sanity check mismatched units
    if (num.unit !== unit) throw Err("point unit != $action unit: $unit != $num.unit")
    return val
  }

  ** Get the standard point details string
  static Str pointDetails(PointLib lib, Dict pt, Bool includeSummary)
  {
    // send messages to managers
    ws := lib.writeMgr.details(pt.id)
    hs := lib.hisCollectMgr.details(pt.id)

    // TODO: connector details....

    // format as string
    s := StrBuf()
    if (includeSummary) s.add(toSummary(pt))
    if (hs != null) s.add("\n").add(hs)
    if (ws != null) s.add("\n").add(ws)
    return s.toStr
  }

  private static Str toSummary(Dict pt)
  {
    kind := pt["kind"]
    unit := pt["unit"]
    tz   := pt["tz"]

    return
      """id:    $pt.id.toCode
         dis:   $pt.dis
         conn:  No Connector
         kind:  $kind
         unit:  $unit
         tz:    $tz
         """
    }


}