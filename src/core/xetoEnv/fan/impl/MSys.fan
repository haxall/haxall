//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Feb 2023  Brian Frank  Creation
//

using util
using xeto

**
** Sys library constants
**
@Js
const class MSys
{
  new make(XetoLib lib)
  {
    x := lib.m.specsMap
    this.obj      = x.get("Obj")
    this.none     = x.get("None")
    this.self     = x.get("Self")
    this.seq      = x.get("Seq")
    this.dict     = x.get("Dict")
    this.list     = x.get("List")
    this.grid     = x.get("Grid")
    this.lib      = x.get("Lib")
    this.spec     = x.get("Spec")
    this.scalar   = x.get("Scalar")
    this.marker   = x.get("Marker")
    this.bool     = x.get("Bool")
    this.str      = x.get("Str")
    this.uri      = x.get("Uri")
    this.number   = x.get("Number")
    this.int      = x.get("Int")
    this.duration = x.get("Duration")
    this.date     = x.get("Date")
    this.time     = x.get("Time")
    this.dateTime = x.get("DateTime")
    this.ref      = x.get("Ref")
    this.enum     = x.get("Enum")
    this.and      = x.get("And")
    this.or       = x.get("Or")
    this.query    = x.get("Query")
  }

  const XetoSpec obj
  const XetoSpec none
  const XetoSpec self
  const XetoSpec seq
  const XetoSpec list
  const XetoSpec dict
  const XetoSpec grid
  const XetoSpec lib
  const XetoSpec spec
  const XetoSpec scalar
  const XetoSpec marker
  const XetoSpec bool
  const XetoSpec str
  const XetoSpec uri
  const XetoSpec number
  const XetoSpec int
  const XetoSpec duration
  const XetoSpec date
  const XetoSpec time
  const XetoSpec dateTime
  const XetoSpec ref
  const XetoSpec enum
  const XetoSpec and
  const XetoSpec or
  const XetoSpec query
}

