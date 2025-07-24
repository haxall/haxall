//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    3 Sep 2013  Brian Frank  Creation
//   22 Apr 2016  Brian Frank  Initial 3.0 port from GridUtil
//

using xeto
using haystack

**
** Utilities for AxonFuncs
**
@Js
internal const class AxonFuncsUtil
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
      list := ((List)val).dup
      if (sorter == null) return ascending ? list.sort : list.sortr
      if (func != null)   return ascending ? list.sort(func) : list.sortr(func)
    }

    if (val is Grid)
    {
      grid := (Grid)val
      if (sorter is Str) return ascending ? grid.sortCol(sorter) : grid.sortColr(sorter)
      if (func != null)  return ascending ? grid.sort(func) : grid.sortr(func)
    }

    throw AxonFuncs.argErr("sort", val)
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

//////////////////////////////////////////////////////////////////////////
// Func Reflection
//////////////////////////////////////////////////////////////////////////

  ** Find all the top-levels functions in the current project
  static Grid funcs(AxonContext cx, Expr filterExpr := Literal.nullVal)
  {
    Filter? filter := null
    if (filterExpr !== Literal.nullVal)
      filter = filterExpr.evalToFilter(cx)

    // iterate the namespace: skip nodoc and filter mismatches
    acc := Dict[,]
    cx.ns.libs.each |lib|
    {
      lib.funcs.each |func|
      {
        meta := func.meta
        if (meta.has("nodoc")) return
        meta = Etc.dictSet(meta, "qname", func.qname)
        if (filter != null && !filter.matches(meta, cx)) return
        acc.add(meta)
      }
    }

    // strip src for security
    names := Etc.dictsNames(acc)
    names.remove("axon")
    names.moveTo("qname", 0)
    return GridBuilder().addColNames(names).addDictRows(acc).toGrid
  }

  ** Find a top-level function by name and return its tags.
  static Dict? func(AxonContext cx, Obj name, Bool checked)
  {
    fn := coerceToFn(cx, name, checked)
    if (fn == null) return null
    return fnToDict(cx, fn)
  }

  ** Find a top-level function by name and return its tags.
  static Grid? compDef(AxonContext cx, Obj name, Bool checked)
  {
    fn := coerceToFn(cx, name, checked)
    if (fn == null) return null
    comp := fn as CompDef ?: throw Err("Func is not a comp: $fn.name")

    cols := Etc.dictsNames(comp.cells)
    cols.remove("name")

    gb := GridBuilder().addCol("name").addColNames(cols)
    gb.setMeta(fnToDict(cx, fn))
    comp.cells.each |cell|
    {
      row := Obj?[,]
      row.capacity = 1 + cols.size
      row.add(cell.name)
      cols.each |n| { row.add(cell[n]) }
      gb.addRow(row)
    }
    return gb.toGrid
  }

  ** Get the current top-level function's tags.
  static Dict curFunc(AxonContext cx)
  {
    def := coerceToFn(cx, cx.curFunc, false)
    if (def == null) throw Err("No top-level func active")
    return fnToDict(cx, def)
  }

  ** Reflect parameters for given function
  static Grid params(AxonContext cx, Fn fn)
  {
    rows := Obj[,]
    fn.params.each |p|
    {
      def :=  p.def?.eval(cx)
      rows.add([p.name, def])
    }
    return Etc.makeListsGrid(null, ["name", "def"], null, rows)
  }

  ** Coerce object to Fn instance
  private static TopFn? coerceToFn(AxonContext cx, Obj x, Bool checked)
  {
    if (x is Str) return cx.resolveTopFn(x, checked)
    if (x is Fn)
    {
      // if closure then its named {top}.{closure}
      name := ((Fn)x).name
      dot := name.index(".")
      if (dot != null) name = name[0..<dot]
      return cx.resolveTopFn(name, checked)
    }
    if (x is Dict && ((Dict)x).has("id")) x = x->id
    /* old 3.1 behavior
    if (x is Ref)
    {
      rec := cx.deref(x)
      if (rec == null)
      {
        if (checked) throw UnknownFuncErr(x.toStr)
        return null
      }
      name := rec["name"] as Str ?: ((Symbol)rec->def).name
      return cx.findTop(name)
    }
    */
    throw ArgErr("Invalid func name argument [$x.typeof]")
  }

  ** We create appropiate meta for TopFn when we parse as thunk
  private static Dict fnToDict(AxonContext cx, TopFn fn)
  {
    fn.meta
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

