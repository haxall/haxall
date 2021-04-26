//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    3 Sep 2013  Brian Frank  Creation
//   22 Apr 2016  Brian Frank  Initial 3.0 port from GridUtil
//

using haystack

**
** Utilities for CoreLib
**
@Js
internal const class CoreLibUtil
{
  static Obj? sort(Obj val, Obj? sorter, Bool ascending)
  {
    Func? func := null
    if (sorter is Fn)
    {
      cx := AxonContext.curAxon
      args := [null, null]
      fn := (Fn)sorter
      func = |Obj? a,Obj? b->Int| { ((Number)fn.call(cx, args.set(0, a).set(1, b))).toInt }
    }

    if (val is List)
    {
      list := ((List)val).rw
      if (sorter == null) return ascending ? list.sort : list.sortr
      if (func != null)   return ascending ? list.sort(func) : list.sortr(func)
    }

    if (val is Grid)
    {
      grid := (Grid)val
      if (sorter is Str) return ascending ? grid.sortCol(sorter) : grid.sortColr(sorter)
      if (func != null)  return ascending ? grid.sort(func) : grid.sortr(func)
    }

    throw CoreLib.argErr("sort", val)
  }

  static Grid gridColKinds(Grid g)
  {
    gb := GridBuilder().addCol("name").addCol("kind").addCol("count")
    g.cols.each |col|
    {
      usage := TagNameUsage()
      g.each |row| { usage.add(row.val(col)) }
      gb.addRow([col.name, usage.toKind, Number(usage.count)])
    }
    return gb.toGrid
  }
}

**************************************************************************
** TagNameUsage
**************************************************************************

** Helper class used by count occurances and kinds of tags
@NoDoc @Js class TagNameUsage
{
  Str toKind()
  {
    s := StrBuf()
    if (marker)   s.join("Marker",   "|")
    if (str)      s.join("Str",      "|")
    if (ref)      s.join("Ref",      "|")
    if (number)   s.join("Number",   "|")
    if (bool)     s.join("Bool",     "|")
    if (bin)      s.join("Bin",      "|")
    if (uri)      s.join("Uri",      "|")
    if (dateTime) s.join("DateTime", "|")
    if (date)     s.join("Date",     "|")
    if (time)     s.join("Time",     "|")
    if (coord)    s.join("Coord",    "|")
    if (list)     s.join("List",     "|")
    if (dict)     s.join("Dict",     "|")
    if (grid)     s.join("Grid",     "|")
    if (symbol)   s.join("Symbol",   "|")
    return s.toStr
  }

  Void add(Obj? val)
  {
    if (val == null) return
    count++
    kind := Kind.fromVal(val, false)
    if (kind === Kind.marker)   { marker   = true; return }
    if (kind === Kind.str)      { str      = true; return }
    if (kind === Kind.ref)      { ref      = true; return }
    if (kind === Kind.number)   { number   = true; return }
    if (kind === Kind.bool)     { bool     = true; return }
    if (kind === Kind.bin)      { bin      = true; return }
    if (kind === Kind.uri)      { uri      = true; return }
    if (kind === Kind.dateTime) { dateTime = true; return }
    if (kind === Kind.date)     { date     = true; return }
    if (kind === Kind.time)     { time     = true; return }
    if (kind === Kind.coord)    { coord    = true; return }
    if (kind === Kind.dict)     { dict     = true; return }
    if (kind === Kind.grid)     { grid     = true; return }
    if (kind === Kind.symbol)   { symbol   = true; return }
    if (kind.isList)            { list     = true; return }
  }

  Int count
  Bool marker
  Bool str
  Bool ref
  Bool number
  Bool bool
  Bool bin
  Bool uri
  Bool dateTime
  Bool date
  Bool time
  Bool coord
  Bool list
  Bool dict
  Bool grid
  Bool symbol
}



