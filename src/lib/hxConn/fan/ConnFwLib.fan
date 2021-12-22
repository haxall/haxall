//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using haystack
using hx

**
** Connector framework library
**
@NoDoc
const class ConnFwLib : HxLib
{
  override HxService[] services() { [ConnRegistryService(rt)] }
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