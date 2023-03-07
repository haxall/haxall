//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Feb 2023  Brian Frank  Creation
//

using util
using data

**
** Sys library constants
**
@Js
internal const class MSys
{
  new make(XetoLib lib)
  {
    x := lib.slotsOwn
    this.obj      = x.get("Obj")
    this.none     = x.get("None")
    this.seq      = x.get("Seq")
    this.dict     = x.get("Dict")
    this.list     = x.get("List")
    this.dataset  = x.get("DataSet")
    this.lib      = x.get("Lib")
    this.spec     = x.get("Spec")
    this.type     = x.get("Type")
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
    this.maybe    = x.get("Maybe")
    this.and      = x.get("And")
    this.or       = x.get("Or")
    this.query    = x.get("Query")
  }

  const XetoType obj
  const XetoType none
  const XetoType dict
  const XetoType seq
  const XetoType list
  const XetoType dataset
  const XetoType lib
  const XetoType spec
  const XetoType type
  const XetoType scalar
  const XetoType marker
  const XetoType bool
  const XetoType str
  const XetoType uri
  const XetoType number
  const XetoType int
  const XetoType duration
  const XetoType date
  const XetoType time
  const XetoType dateTime
  const XetoType ref
  const XetoType maybe
  const XetoType and
  const XetoType or
  const XetoType query
}