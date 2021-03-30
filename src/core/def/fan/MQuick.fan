//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Dec 2018  Brian Frank  Creation
//

using haystack

**
** MQuick caches commonly used defs for quick access.  Quick constants
** are only for core built-in defs managed by the "root" MBuiltNamespace.
** Overlays always share this instance from their base namespace.
**
@NoDoc @Js
const class MQuick
{

  internal new make(MNamespace ns)
  {
    this.ph       = ns.def("lib:ph")

    this.val      = ns.def("val")
    this.marker   = ns.def("marker")
    this.na       = ns.def("na")
    this.remove   = ns.def("remove")
    this.bool     = ns.def("bool")
    this.number   = ns.def("number")
    this.str      = ns.def("str")
    this.uri      = ns.def("uri")
    this.ref      = ns.def("ref")
    this.date     = ns.def("date")
    this.time     = ns.def("time")
    this.dateTime = ns.def("dateTime")
    this.coord    = ns.def("coord")
    this.xstr     = ns.def("xstr")

    this.list     = ns.def("list")
    this.grid     = ns.def("grid")
    this.dict     = ns.def("dict")

    this.def      = ns.def("def")
    this.entity   = ns.def("entity")
    this.tags     = ns.def("tags")
    this.choice   = ns.def("choice")
  }

  const Lib ph

  const Def val
  const Def marker
  const Def na
  const Def remove
  const Def bool
  const Def number
  const Def str
  const Def uri
  const Def ref
  const Def date
  const Def time
  const Def dateTime
  const Def coord
  const Def xstr

  const Def list
  const Def grid
  const Def dict

  const Def def
  const Def entity
  const Def tags
  const Def choice

  Def? fromFixedType(Type type)
  {
    if (type === Number#)    return number
    if (type === Marker#)    return marker
    if (type === Str#)       return str
    if (type === Ref#)       return ref
    if (type === DateTime#)  return dateTime
    if (type === Bool#)      return bool
    if (type === NA#)        return na
    if (type === Coord#)     return coord
    if (type === Uri#)       return uri
    if (type === Date#)      return date
    if (type === Time#)      return time
    if (type === XStr#)      return xstr
    if (type === Remove#)    return remove
    return null
  }

}

