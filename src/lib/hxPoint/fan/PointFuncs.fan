//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Jul 2012  Brian Frank  Creation
//

using haystack
using axon
using hx

**
** Point module Axon functions
**
const class PointFuncs
{
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
      val = TimedOverride(val, duration.toDuration)
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
  static Obj? pointWrite(Obj point, Obj? val, Number? level, Obj? who := null)
  {
    cx := curContext
    if (level == null) throw ArgErr("level arg is null")
    if (who == null) who = cx.user.dis
    return lib(cx).writeMgr.write(HxUtil.toRec(cx.rt, point), val, level.toInt, who).get(timeout)
  }

  **
  ** Used by the pointOverride command to issue an override using the
  ** current users access control permissions via pointOverrideAccess tag.
  **
  @NoDoc @Axon
  static Obj? pointOverrideCommand(Obj point, Obj? val, Number level, Number? duration := null)
  {
    // echo("--  pointOverrideCommand $point = $val @ $level [$duration]")

    // first make sure user can read this point
    cx := curContext
    lib := lib(cx)
    rec := cx.db.readById(HxUtil.toId(point))

    // now check access permissions
/* TODO
    if (!cx.user.access.pointOverride.canOverrideLevel(level.toInt))
      throw PermissionErr("Cannot override level: $level")
*/

    // wrap val for overrides with a duration
    if (level.toInt == 8 && val != null && duration != null)
      val = TimedOverride(val, duration.toDuration)

    return lib.writeMgr.write(rec, val, level.toInt, cx.user.dis).get(timeout)
  }

  ** Handle pointWrite as Haystack API operation
/* TODO
  private static Obj? pointWriteOp(HxContext cx, Grid req)
  {
    // parse request
    if (req.size != 1) throw Err("Request grid must have 1 row")
    reqRow := req.first
    rec := cx.readById(reqRow.id)

    // if reading level will be null
    level := reqRow["level"] as Number
    if (level == null) return pointWriteArray(rec)

    // handlw write
    cx.checkAdmin("pointWrite op")
    val := reqRow["val"]
    who := reqRow["who"]?.toStr ?: cx.user.dis
    dur := reqRow["duration"] as Number

    who = "Haystack.pointWrite | $who"

    // if have timed override
    if (val != null && level.toInt == 8 && dur != null)
      val = TimedOverride(val, dur.toDuration)

    return PointExt.cur.write(rec, val, level.toInt, who).get(timeout)
  }
*/

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
    lib(curContext).writeMgr.array(HxUtil.toId(point))
  }

  **
  ** Evaluate a [point conversion]`ext-point::doc#convert`. First
  ** parameter is point to test (anything accepted by `toRec`) or null
  ** to use empty dict.
  **
  ** Examples:
  **   pointConvert(null, "+ 2 * 10", 3)
  **   pointConvert(null, "hexToNumber()", "ff")
  **
  @Axon
  static Obj? pointConvert(Obj? pt, Str convert, Obj? val)
  {
    cx := curContext
    lib := lib(cx)
    rec := pt == null ? Etc.emptyDict : HxUtil.toRec(cx.rt, pt)
    return PointConvert.fromStr(convert).convert(lib, rec, val)
  }

  ** Get debug string for writables, his collections
  @NoDoc @Axon
  static Str pointDetails(Obj point)
  {
    cx  := curContext
    rec := HxUtil.toRec(cx.rt, point)
    return PointUtil.pointDetails(lib(cx), rec, true)
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
    lib := lib(curContext)
    lib.rt.sync
    enums := lib.enums
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
    lib := lib(curContext)
    lib.rt.sync
    return lib.enums.get(id, checked)?.grid
  }

  ** Write all hisCollect items buffered in memory to the historian.
  ** Block until complete or until timeout exceeded.
/* TODO
  @Axon { admin = true }
  static Obj? hisCollectWriteAll(Number? timeout := null)
  {
    lib(curContext).hisMgr.hisCollectWriteAll.get(timeout?.toDuration)
  }
*/

  ** Legacy support
  @Deprecated @NoDoc @Axon { admin = true }
  static Obj? pointExtSync() { curContext.rt.sync; return null }

  ** Current context
  private static HxContext curContext() { HxContext.curHx }

  ** Lookup PointLib for context
  private static PointLib lib(HxContext cx) { cx.rt.lib("point") }

  internal static const Duration timeout := 30sec
  internal static const Number level1   := Number(1)
  internal static const Number level8   := Number(8)
  internal static const Number levelDef := Number(17)
}


