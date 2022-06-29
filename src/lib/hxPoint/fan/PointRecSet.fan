//
// Copyright (c) 2022, SkyFoundry LLC
// All Rights Reserved
//
// History:
//   27 Mar 2022  Brian Frank  Creation
//

using haystack
using hx

**
** Point rec set is used to map containment for site,
** space, equip, device, and point
**
internal class PointRecSet
{
  new make(Obj? recs, HxContext cx := HxContext.curHx)
  {
    this.recs = Etc.toRecs(recs, cx)
    this.cx   = cx
  }

  Grid toSites() { map("site", "siteRef") }

  Grid toSpaces() { map("space", "spaceRef") }

  Grid toEquips() { map("equip", "equipRef") }

  Grid toDevices() { map("device", "deviceRef") }

  Grid toPoints() { map("point", "pointRef") }

  private Grid map(Str markerTag, Str refTag)
  {
    // handle common case for one target rec
    if (recs.size == 1)
      return Etc.makeDictsGrid(null, mapRec(recs.first, markerTag, refTag))

    // map each record and join results together by id
    join := Ref:Dict[:]
    recs.each |rec|
    {
      mapRec(rec, markerTag, refTag).each |x| { join[x.id] = x }
    }
    return Etc.makeDictsGrid(null, join.vals)
  }

  private Dict[] mapRec(Dict rec, Str markerTag, Str refTag)
  {
    // if rec has the tag, then return it
    if (rec.has(markerTag)) return [rec]

    // if rec has reference tag, find parent
    ref := rec[refTag] as Ref
    if (ref != null) return [cx.db.readById(ref)]

    // check for parent types
    if (rec.has("equip"))  return children(markerTag, "equipRef",  rec.id)
    if (rec.has("site"))   return children(markerTag, "siteRef",   rec.id)
    if (rec.has("space"))  return children(markerTag, "spaceRef",  rec.id)
    if (rec.has("device")) return children(markerTag, "deviceRef", rec.id)
    if (rec.has("weatherStation")) return children(markerTag, "weatherStationRef", rec.id)

    return Dict#.emptyList
  }

  private Dict[] children(Str markerTag, Str parentRef, Ref parentId)
  {
    cx.db.readAllList(Filter.has(markerTag).and(Filter.eq(parentRef, parentId)))
  }

  private Dict[] recs
  private HxContext cx
}

