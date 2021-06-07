//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Jun 2021  Brian Frank  Creation
//

using haystack
using axon
using folio

**
** Haxall utility methods
**
const class HxUtil
{

//////////////////////////////////////////////////////////////////////////
// Folio Utils
//////////////////////////////////////////////////////////////////////////

  ** Coerce a value to a Ref identifier:
  **   - Ref returns itself
  **   - Row or Dict, return 'id' tag
  **   - Grid return first row id
  static Ref toId(Obj? val)
  {
    if (val is Ref) return val
    if (val is Dict) return ((Dict)val).id
    if (val is Grid) return ((Grid)val).first.id
    throw Err("Cannot convert to id: ${val?.typeof}")
  }

  ** Coerce a value to a list of Ref identifiers:
  **   - Ref returns itself as list of one
  **   - Ref[] returns itself
  **   - Dict return 'id' tag
  **   - Dict[] return 'id' tags
  **   - Grid return 'id' column
  static Ref[] toIds(Obj? val)
  {
    if (val is Ref) return Ref[val]
    if (val is Dict) return Ref[((Dict)val).id]
    if (val is List)
    {
      list := (List)val
      if (list.isEmpty) return Ref[,]
      if (list.of.fits(Ref#)) return list
      if (list.all |x| { x is Ref }) return Ref[,].addAll(list)
      if (list.all |x| { x is Dict }) return list.map |Dict d->Ref| { d.id }
    }
    if (val is Grid)
    {
      grid := (Grid)val
      if (grid.meta.has("navFilter"))
        return Slot.findMethod("legacy::NavFuncs.toNavFilterRecIdList").call(grid)
      ids := Ref[,]
      idCol := grid.col("id")
      grid.each |row|
      {
        id := row.val(idCol) as Ref ?: throw Err("Row missing id tag")
        ids.add(id)
      }
      return ids
    }
    throw Err("Cannot convert to ids: ${val?.typeof}")
  }

  ** Implementation for readAllTagNames function
  internal static Grid readAllTagNames(Folio db, Filter filter)
  {
    acc := Str:TagNameUsage[:]
    db.readAllEachWhile(filter, Etc.emptyDict) |rec|
    {
      rec.each |v, n|
      {
        u := acc[n]
        if (u == null) acc[n] = u = TagNameUsage()
        u.add(v)
      }
      return null
    }
    gb := GridBuilder().addCol("name").addCol("kind").addCol("count")
    acc.keys.sort.each |n|
    {
      u := acc[n]
      gb.addRow([n, u.toKind, Number(u.count)])
    }
    return gb.toGrid
  }

  ** Implementation for readAllTagVals function
  internal static Obj[] readAllTagVals(Folio db, Filter filter, Str tagName)
  {
    acc := Obj:Obj[:]
    db.readAllEachWhile(filter, Etc.emptyDict) |rec|
    {
      val := rec[tagName]
      if (val != null) acc[val] = val
      return acc.size > 200 ? "break" : null
    }
    return acc.vals.sort
  }

  ** Get current context
  private static HxContext curContext() { HxContext.curHx }


}