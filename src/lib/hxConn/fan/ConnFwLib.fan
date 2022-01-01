//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using haystack
using obs
using hx

**
** Connector framework library
**
@NoDoc
const class ConnFwLib : HxLib
{
  ** Publish HxConnRegistryService
  override HxService[] services() { [ConnRegistryService(rt)] }

  ** List the configured connTuning records
  const ConnTuningRoster tunings := ConnTuningRoster()

  ** Start callback
  override Void onStart()
  {
    observe("obsCommits",
        Etc.makeDict([
          "obsAdds":      Marker.val,
          "obsUpdates":   Marker.val,
          "obsRemoves":   Marker.val,
          "obsAddOnInit": Marker.val,
          "syncable":     Marker.val,
          "obsFilter":   "connTuning"
        ]), #onConnTuningEvent)
  }

  ** Handle commit event on a connTuning rec
  internal Void onConnTuningEvent(CommitObservation e)
  {
    tunings.onEvent(e)
  }

}

**************************************************************************
** ConnRegistry
**************************************************************************

**
** ConnRegistryService
**
internal const class ConnRegistryService : HxConnRegistryService
{
  new make(HxRuntime rt)
  {
    map := Str:HxConnService[:]

    rt.libs.list.each |lib|
    {
      c := lib as HxConnService
      if (c != null) map[c.name] = c
    }

    this.map = map
    this.list = map.vals.sort |a, b| { a.name <=> b.name }
    this.connRefTags = this.list.map |c->Str| { c.name + "ConnRef" }
  }

  override const HxConnService[] list

  override const Str[] connRefTags

  const Str:HxConnService map

  override HxConnService? byName(Str name, Bool checked := true)
  {
    c := map[name]
    if (c != null) return c
    if (checked) throw UnknownNameErr(name)
    return null
  }

  override HxConnService? byConn(Dict conn, Bool checked := true)
  {
    for (i := 0; i<list.size; ++i)
    {
      c := list[i]
      if (conn.has(c.connTag)) return c
    }
    if (checked) throw Err("Not a conn: $conn.id.toZinc")
    return null
  }

  override HxConnService? byPoint(Dict point, Bool checked := true)
  {
    for (i := 0; i<list.size; ++i)
    {
      c := list[i]
      if (point.has(c.connRefTag)) return c
    }
    if (checked) throw Err("Point not bound to a conn: $point.id.toZinc")
    return null
  }

  override HxConnService? byPoints(Dict[] points, Bool checked := true)
  {
    conn := byPoint(points.first ?: Etc.emptyDict, checked)
    for (i := 1; i<points.size; ++i)
    {
      connX := byPoint(points[i], checked)
      if (conn !== connX)
      {
        if (checked) throw Err("Points do not have same conn")
        return null
      }
    }
    return conn
  }

  override Ref? connRef(Dict point, Bool checked := true)
  {
    for (i := 0; i<list.size; ++i)
    {
      ref := point[list[i].connRefTag] as Ref
      if (ref != null) return ref
    }
    if (checked) throw Err("Not bound to conn: $point.id.toZinc")
    return null
  }
}