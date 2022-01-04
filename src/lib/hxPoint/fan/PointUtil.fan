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
  static Str pointDetails(PointLib lib, Dict pt, Bool isTop)
  {
    // connector details
    if (isTop)
    {
      // for 3.1.0 we are using old connector framework so a result
      // from this will include the summary, his collect, and write info
      cp := lib.rt.conn.point(pt.id, false)
      if (cp != null) return cp.details
    }

    // send messages to managers
    ws := lib.writeMgr.details(pt.id)
    hs := lib.hisCollectMgr.details(pt.id)

    // format as string
    s := StrBuf()
    if (isTop) s.add(toSummary(pt))
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
         kind:  $kind
         unit:  $unit
         tz:    $tz
         """
    }

  /* Debug support
  static Str[] debugs() { debugActor.send("_list").get(null) }
  static Void debug(Str msg) { debugActor.send(msg) }
  static const Actor debugActor := Actor(ActorPool()) |msg|
  {
    list := Actor.locals["x"] as Str[]
    if (list == null) Actor.locals["x"] = list = Str[,]
    if (msg.toStr == "_list") return list.dup.toImmutable
    list.add(msg)
    return null
  }
  */

}