//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jul 2021  Brian Frank  Creation
//

using concurrent
using xeto
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

    // if number provided is unitless, then use point's unit
    if (num.unit == null) return Number(num.toFloat, unit)

    // sanity check mismatched units
    if (num.unit !== unit) throw Err("point unit != $action unit: $unit != $num.unit")
    return val
  }

  ** Get the standard point details string
  static Str pointDetails(PointExt ext, Dict pt, Bool isTop)
  {
    // connector details
    if (isTop)
    {
      // for 3.1.0 we are using old connector framework so a result
      // from this will include the summary, his collect, and write info
      cp := ext.proj.exts.conn(false)?.point(pt.id, false)
      if (cp != null) return cp.details
    }

    // send messages to managers
    ws := ext.writeMgr.details(pt.id)
    hs := ext.hisCollectMgr.details(pt.id)

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

  ** Implementation for the toOccupied function
  static Dict? toOccupied(Dict r, Bool checked, Context cx)
  {
    occupied := Filter("occupied")

    // if equip then lookup up equip hierarchy for match
    if (r.has("equip"))
    {
      // try to find match on this equip
      occ := cx.db.read(occupied.and(Filter.eq("equipRef", r.id)), false)
      if (occ != null) return occ

      // find on parent equip
      occ = toParentEquipOccupied(r, cx)
      if (occ != null) return occ

      // find on parent space
      occ = toParentSpaceOccupied(r, cx)
      if (occ != null) return occ
    }

    // if space then lookup up space hierarchy for match
    if (r.has("space"))
    {
      // try to find match on this space
      occ := cx.db.read(occupied.and(Filter.eq("spaceRef", r.id)), false)
      if (occ != null) return occ

      // find on parent parent
      occ = toParentSpaceOccupied(r, cx)
      if (occ != null) return occ
    }

    // if point, try parent equip then try parent space
    if (r.has("point"))
    {
      // find on parent equip
      occ := toParentEquipOccupied(r, cx)
      if (occ != null) return occ

      // find on parent space
      occ = toParentSpaceOccupied(r, cx)
      if (occ != null) return occ
    }

    // get all site level occupied points
    Ref siteId := r.has("site") ? r.id : r->siteRef
    recs := cx.db.readAll(occupied.and(Filter.eq("siteRef", siteId)).and(Filter.has("sitePoint")))
    if (recs.size == 1) return recs.first
    if (checked)
    {
      if (recs.size == 0)
        throw Err("No 'occupied' point found for $r.id.toZinc")
      else
        throw Err("Multiple 'sitePoint occupied' matches")
    }
    return null
  }

  ** Check for occupied point in parent spaceRef or return null
  private static Dict? toParentSpaceOccupied(Dict r, Context cx)
  {
    spaceRef := r["spaceRef"] as Ref
    if (spaceRef == null) return null
    return toOccupied(cx.db.readById(spaceRef), false, cx)
  }

  ** Check for occupied point in parent equipRef or return null
  private static Dict? toParentEquipOccupied(Dict r, Context cx)
  {
    equipRef := r["equipRef"] as Ref
    if (equipRef == null) return null
    return toOccupied(cx.db.readById(equipRef), false, cx)
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

