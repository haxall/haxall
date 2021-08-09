//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Aug 2012  Brian Frank  Creation
//

using concurrent
using haystack
using folio

**
** DemoMgrActor wraps the DemoMgr
**
internal const class DemoMgrActor : PointMgrActor
{
  new make(PointLib lib) : super(lib, 1sec, DemoMgr#) {}
}

**************************************************************************
** DemoMgr
**************************************************************************

**
** DemoMgr is used to generate random, changing curVal for
** all points which aren't explicitly associated with a connector
**
internal class DemoMgr : PointMgr
{
  new make(PointLib lib) : super(lib) { this.db = lib.rt.db }

  const Folio db

  override Void onCheck()
  {
    // update cycle count
    cycle++

    // find all installed connector exts to get their connector tags
    connTags := lib.rt.conns.connRefTags

    // process all the points not associated with connector
    now := Duration.now
    recs := db.readAll(Filter.has("point"))
    recs.each |rec|
    {
      // if noDemoMode, schedule/calendar, or associated with a connector skip it
      if (rec.missing("cur")) return
      if (rec.has("noDemoMode")) return
      if (rec.has("curSource")) return
      if (rec.has("point") && rec["weatherStationRef"] is Ref) return
      if (rec.has("schedule") || rec.has("calendar")) return
      if (connTags.any |tag| { rec.has(tag) }) return

      // process the point
      try
      {
        kind := rec["kind"]
        if (kind == "Number") checkNumber(rec)
        else if (kind == "Bool") checkBool(rec)
        else if (kind == "Str") checkStr(rec)
      }
      catch (ShutdownErr e) {}
      catch (Err e) { e.trace }
    }
  }

  Void checkNumber(Dict rec)
  {
    range := toNumberRange(rec)
    span := (range.end - range.start).toFloat
    mid :=  range.start.toFloat + span / 2f
    unit := Number.loadUnit(rec["unit"] ?: "????", false)

    // setpoint
    if (rec.has("sp"))
    {
      updatePoint(rec, Number(mid, unit))
      return
    }

    // generate sine range
    pointCycle := cycle + rec.id.hash.and(0xff)
    sin := (pointCycle / 10f).sin
    val := mid + span/2*sin
    val = (val * 10).round / 10f
    updatePoint(rec, Number(val, unit))
  }

  Range toNumberRange(Dict rec)
  {
    // check for explicit minVal/maxVal
    min := rec["minVal"] as Number
    max := rec["maxVal"] as Number
    if (min != null && max != null) return min.toInt .. max.toInt

    // unit based default
    unit := rec["unit"] ?: "%"
    rand := rec.id.hash % 100
    switch (unit)
    {
      case "\u00B0F":    return rec.has("zone") ? 66..80 : 50..80
      case "\u00B0C":    return rec.has("zone") ? 18..27 : 10..27
      case "kW":
      case "kWh":        return (700+rand)..(1000+rand*2)
      case "inH\u2082O": return 2..0
      default:           return 0..100
    }
  }

  Void checkBool(Dict rec)
  {
    // only update bools every 5sec
    if (cycle % 5 != 0) return

    val := rec["curVal"] as Bool
    if (val == null) val = (1..100).random > 50
    updatePoint(rec, !val)
  }

  Void checkStr(Dict rec)
  {
    // only update bools every 5sec
    if (cycle % 5 != 0) return

    enum := rec["enum"] as Str
    if (enum == null) return
    vals := enum.split(',')
    if (vals.size < 2) return

    val := rec["curVal"] as Str
    if (val == null) val = vals.first
    index := vals.index(val) ?: 0
    index++
    if (index >= vals.size) index = 0
    updatePoint(rec, vals[index])
  }

  Void updatePoint(Dict rec, Obj val)
  {
    writeVal := rec["writeVal"]
    if (writeVal != null) val = writeVal
    db.commitAsync(Diff(rec, Etc.makeDict2("curVal", val, "curStatus", "ok"), Diff.forceTransient))
  }

  Int cycle    // current demo cycle

}

