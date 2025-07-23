//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Jul 2012  Brian Frank  Creation
//

using xeto
using haystack
using axon
using hx

**
** Point module Axon functions
**
const class PointFuncs
{
  **
  ** Map a set of recs to to a grid of [sites]`site`.  The 'recs'
  ** parameter may be any value accepted by `toRecList()`.  Return empty
  ** grid if no mapping is found.  The following mappings are supported:
  **  - recs with 'site' tag are mapped as themselves
  **  - recs with 'siteRef' tag are mapped to their parent site
  **
  ** Examples:
  **   read(site).toSites     // return site itself
  **   read(space).toSites    // return space's parent site
  **   read(equip).toSites    // return equip's parent site
  **   read(point).toSites    // return point's parent site
  **
  @Axon
  static Grid toSites(Obj? recs)
  {
    PointRecSet(recs).toSites
  }

  **
  ** Map a set of recs to to a grid of [spaces]`space`.  The 'recs'
  ** parameter may be any value accepted by `toRecList()`.  Return empty
  ** grid if no mapping is found.  The following mappings are supported:
  **  - recs with 'space' tag are mapped as themselves
  **  - recs with 'spaceRef' tag are mapped to their parent space
  **  - recs with 'site' are mapped to spaces with parent 'siteRef'
  **
  ** Examples:
  **   read(site).toSpaces      // return children spaces within site
  **   read(equip).toSpaces     // return equip's parent space
  **   read(point).toSpaces     // return point's parent space
  **   read(space).toSpaces     // return space itself
  **
  @Axon
  static Grid toSpaces(Obj? recs)
  {
    PointRecSet(recs, curContext).toSpaces
  }

  **
  ** Map a set of recs to to a grid of [equips]`equip`.  The 'recs'
  ** parameter may be any value accepted by `toRecList()`.  Return empty
  ** grid if no mapping is found.  The following mappings are supported:
  **  - recs with 'equip' tag are mapped as themselves
  **  - recs with 'equipRef' tag are mapped to their parent equip
  **  - recs with 'site' are mapped to equip with parent 'siteRef'
  **  - recs with 'space' are mapped to equip with parent 'spaceRef'
  **
  ** Examples:
  **   read(site).toEquips      // return children equip within site
  **   read(space).toEquips     // return children equip within space
  **   read(equip).toEquips     // return equip itself
  **   read(point).toEquips     // return point's parent equip
  **
  @Axon
  static Grid toEquips(Obj? recs)
  {
    PointRecSet(recs, curContext).toEquips
  }

  **
  ** Map a set of recs to to a grid of [devices]`device`.  The 'recs'
  ** parameter may be any value accepted by `toRecList()`.  Return empty
  ** grid if no mapping is found.  The following mappings are supported:
  **  - recs with 'device' tag are mapped as themselves
  **  - recs with 'deviceRef' tag are mapped to their parent device
  **  - recs with 'site' are mapped to devices with parent 'siteRef'
  **  - recs with 'space' are mapped to devices with parent 'spaceRef'
  **  - recs with 'equip' are mapped to devices with parent 'equipRef'
  **
  ** Examples:
  **   read(site).toDevices      // return children devices within site
  **   read(space).toDevices     // return children devices within space
  **   read(equip).toDevices     // return children devices within equip
  **   read(point).toDevices     // return point's parent device
  **
  @Axon
  static Grid toDevices(Obj? recs)
  {
    PointRecSet(recs, curContext).toDevices
  }

  **
  ** Map a set of recs to to a grid of [points]`point`.  The 'recs'
  ** parameter may be any value accepted by `toRecList()`.  Return empty
  ** grid if no mapping is found.  The following mappings are supported:
  **  - recs with 'point' tag are mapped as themselves
  **  - recs with 'site' are mapped to points with parent 'siteRef'
  **  - recs with 'space' are mapped to points with parent 'spaceRef'
  **  - recs with 'equip' are mapped to points with parent 'equipRef'
  **  - recs with 'device' are mapped to points with parent 'deviceRef'
  **
  ** Examples:
  **   read(site).toPoints      // return children points within site
  **   read(space).toPoints     // return children points within space
  **   read(equip).toPoints     // return children points within equip
  **   read(device).toPoints    // return children points within device
  **
  @Axon
  static Grid toPoints(Obj? recs)
  {
    PointRecSet(recs, curContext).toPoints
  }

  **
  ** Given a `site`, `space`, `equip`, or `point` rec, get its `occupied`
  ** point.  The following algorithm is used to lookup the occupied point:
  **   1. Try to find in equip or parent of nested equip
  **   2. Try to find in space or parent of nested spaces
  **   3. Try to find in site if site if tagged as `sitePoint`
  **
  ** If there are no matches or multiple ambiguous matches, then return
  ** null or raise an exception based on checked flag.
  **
  @Axon
  static Dict? toOccupied(Obj? rec, Bool checked := true)
  {
    PointUtil.toOccupied(Etc.toRec(rec), checked, curContext)
  }

  **
  ** Given a 'equip' record Dict, return a grid of its points.
  ** If this function is overridden you MUST NOT use an XQuery to
  ** resolve points; this function must return local only points.
  **
  @Axon { meta = ["overridable":Marker("")] }
  static Grid equipToPoints(Obj equip)
  {
    cx := curContext
    rec := Etc.toRec(equip, cx)
    id := rec.id
    if (rec["equip"] !== Marker.val) throw Err("Not equip: $id")
    return cx.db.readAll(Filter.has("point").and(Filter.eq("equipRef", id)))
  }

//////////////////////////////////////////////////////////////////////////
// Point Writes
//////////////////////////////////////////////////////////////////////////

  **
  ** User level-1 manual override of writable point.
  ** See `pointWrite`.
  **
  @Axon { admin = true }
  static Obj? pointEmergencyOverride(Obj point, Obj? val)
  {
    pointWrite(point, val, level1, null)
  }

  **
  ** User level-1 manual auto (override release) of writable point.
  ** See `pointWrite`.
  **
  @Axon { admin = true }
  static Obj? pointEmergencyAuto(Obj point)
  {
    pointWrite(point, null, level1, null)
  }

  **
  ** User level-8 manual override of writable point.
  ** If duration is specified it must be a number with unit of time
  ** that indicates how long to put the point into override.  After
  ** the duration expires, the point is set back to auto (null).
  ** See `pointWrite`.
  **
  @Axon { admin = true }
  static Obj? pointOverride(Obj point, Obj? val, Number? duration := null)
  {
    if (val != null && duration != null)
      val = Etc.dict2("val", val, "duration", duration.toDuration)
    return pointWrite(point, val, level8, null)
  }

  **
  ** User level-8 manual auto (override release) of writable point.
  ** See `pointWrite`.
  **
  @Axon { admin = true }
  static Obj? pointAuto(Obj point)
  {
    pointWrite(point, null, level8, null)
  }

  **
  ** Set the relinquish default value (level-17) of writable point.
  ** See `pointWrite`.
  **
  @Axon { admin = true }
  static Obj? pointSetDef(Obj point, Obj? val)
  {
    pointWrite(point, val, levelDef, null)
  }

  **
  ** Set a writable point's priority array value at the given level.
  ** The point may be any value accepted by `toRec`.  Level must
  ** be 1 to 17 (where 17 represents def value).  The who parameter
  ** is a string which represent debugging information about which
  ** user or application is writing to this priorirty array level.
  ** If who is omitted, then the current user's display string is used
  **
  @Axon { admin = true }
  static Obj? pointWrite(Obj point, Obj? val, Number? level, Obj? who := null, Dict? opts := null)
  {
    cx := curContext
    if (level == null) throw ArgErr("level arg is null")
    if (who == null) who = cx.user.dis
    if (opts == null) opts = Etc.dict0
    return ext(cx).writeMgr.write(Etc.toRec(point), val, level.toInt, who, opts).get(timeout)
  }

  **
  ** Issue a point override command based on current user's access
  ** control permissions
  **
  @Axon
  static Obj? pointOverrideCommand(Obj point, Obj? val, Number level, Number? duration := null)
  {
    // echo("--  pointOverrideCommand $point = $val @ $level [$duration]")

    // first make sure user can read this point
    cx := curContext
    ext := ext(cx)
    rec := cx.db.readById(Etc.toId(point))

    // now check access permissions
    if (!cx.user.access.canPointWriteAtLevel(level.toInt))
      throw PermissionErr("Cannot override level: $level")

    // wrap val for overrides with a duration
    if (level.toInt == 8 && val != null && duration != null)
      val = Etc.dict2("val", val, "duration", duration.toDuration)

    return ext.writeMgr.write(rec, val, level.toInt, cx.user.dis, Etc.dict0).get(timeout)
  }

  **
  ** Return the current priority array state of a writable point.
  ** The point may be any value accepted by `toRec`.  The result is
  ** returned grid with following columns:
  **   - level: number from 1 - 17 (17 is default)
  **   - levelDis: human description of level
  **   - val: current value at level or null
  **   - who: who last controlled the value at this level
  **
  @Axon
  static Grid pointWriteArray(Obj point)
  {
    ext(curContext).writeMgr.arrayById(Etc.toId(point))
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  **
  ** Evaluate a [point conversion]`ext-point::doc#convert`. First
  ** parameter is point to test (anything accepted by `toRec`) or null
  ** to use empty dict.
  **
  ** Examples:
  **   pointConvert(null, "+ 2 * 10", 3)
  **   pointConvert(null, "hexToNumber()", "ff")
  **   pointConvert(null, "°C => °F", 20°C)
  **
  @Axon
  static Obj? pointConvert(Obj? pt, Str convert, Obj? val)
  {
    cx := curContext
    ext := ext(cx)
    rec := pt == null ? Etc.dict0 : Etc.toRec(pt)
    return PointConvert.fromStr(convert).convert(ext, rec, val)
  }

  **
  ** Get debug string for point including writables and his collection.
  ** The argument is anything acceptable by `toRec()`.
  ** The result is returned as a plain text string.
  **
  ** Examples:
  **   read(dis=="My Point").pointDetails
  **   pointDetails(@2b80f96a-820a4f1a)
  **
  @Axon
  static Str pointDetails(Obj point)
  {
    cx  := curContext
    rec := Etc.toRec(point)
    return PointUtil.pointDetails(ext(cx), rec, true)
  }

  ** Return grid of thermistor table names as grid with one 'name' column
  @Axon
  static Grid pointThermistorTables()
  {
    Etc.makeListGrid(null, "name", null, ThermistorConvert.listTables)
  }

  ** Return grid of current enum defs defined by `enumMeta`.
  ** This call forces a refresh of the definitions.
  @Axon static Grid enumDefs()
  {
    ext := ext(curContext)
    ext.proj.sync
    enums := ext.enums
    gb := GridBuilder()
    gb.setMeta(enums.meta)
    gb.addCol("id").addCol("size")
    enums.list.each |e| { gb.addRow2(e.id, Number(e.size)) }
    return gb.toGrid
  }

  ** Return definition of given enum def defined by `enumMeta`
  ** This call forces a refresh of the definitions.
  @Axon static Grid? enumDef(Str id, Bool checked := true)
  {
    ext := ext(curContext)
    ext.proj.sync
    return ext.enums.get(id, checked)?.grid
  }

  **
  ** Return if a point value matches a given critera:
  **   - match any values which are equal via '==' operator
  **   - zero matches false (0% ==> false)
  **   - non-zero matches true (not 0% ==> true)
  **   - numerics can be matches with range
  **   - match can be a function which takes the value
  **
  ** Examples:
  **   matchPointVal(false, false)     >>  true
  **   matchPointVal(0, false)         >>  true
  **   matchPointVal(33, false)        >>  false
  **   matchPointVal(33, true)         >>  true
  **   matchPointVal(33, 0..40)        >>  true
  **   matchPointVal(90, 0..40)        >>  false
  **   matchPointVal(4) x => x.isEven  >>  true
  **
  @Axon static Bool matchPointVal(Obj? val, Obj? match)
  {
    // exact match
    if (val == match) return true

    // zero matches false
    if (match == false)
    {
      if (val is Number && ((Number)val).toFloat == 0f) return true
      return false
    }

    // non-zero matches true
    if (match == true)
    {
      if (val is Number && ((Number)val).toFloat != 0f) return true
      return false
    }

    // range
    if (match is ObjRange && val is Number)
    {
      r := (ObjRange)match
      s := r.start as Number
      e := r.end as Number
      if (s == null || e == null) return false
      sf := s.toFloat
      ef := e.toFloat
      if (ef == 100f) ef = 100.9f  // fuzzy match 100%
      vf := ((Number)val).toFloat
      return sf <= vf && vf <= ef
    }

    // function
    if (match is Fn)
    {
      return (((Fn)match).call(curContext, [val]))
    }

    return false
  }

  ** Write all hisCollect items buffered in memory to the historian.
  ** Block until complete or until timeout exceeded.
  @Axon { admin = true }
  static Obj? hisCollectWriteAll(Number? timeout := null)
  {
    ext(curContext).hisCollectMgr.writeAll.get(timeout?.toDuration)
  }

  ** Force history collector to recreate its watch
  @NoDoc @Axon { su = true }
  static Obj? hisCollectReset(Number? timeout := null)
  {
    ext(curContext).hisCollectMgr.reset.get(timeout?.toDuration)
  }

  ** Legacy support
  @Deprecated @NoDoc @Axon { admin = true }
  static Obj? pointExtSync() { curContext.rt.sync; return null }

  ** Current context
  private static Context curContext() { Context.cur }

  ** Lookup PointExt for context
  private static PointExt ext(Context cx) { cx.proj.ext("hx.point") }

  internal static const Duration timeout := 30sec
  internal static const Number level1   := Number(1)
  internal static const Number level8   := Number(8)
  internal static const Number levelDef := Number(17)
}

