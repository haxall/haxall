//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Dec 2022  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack::Grid
using haystack::Number
using haystack::Ref

**
** Pretty printer
**
@Js
class Printer
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(MEnv env, OutStream out, Dict opts)
  {
    this.env        = env
    this.out        = out
    this.opts       = opts
    this.escUnicode = optBool("escapeUnicode", false)
    this.showdoc    = optBool("doc", false)
    this.specMode   = optSpecMode
    this.indention  = optInt("indent", 0)
    this.width      = optInt("width", terminalWidth)
    this.height     = optInt("height", terminalHeight)
    this.isStdout   = out === Env.cur.out
    this.theme      = isStdout ? PrinterTheme.configured : PrinterTheme.none
  }

//////////////////////////////////////////////////////////////////////////
// Objects
//////////////////////////////////////////////////////////////////////////

  ** Top level print
  This print(Obj? v)
  {
    if (opts.has("json")) return json(v).nl
    if (opts.has("text")) return w(v?.toStr ?: "")

    dict := v as haystack::Dict // TODO
    if (dict != null && dict.has("id"))
      comment("// $dict.id.toZinc").nl

    val(v)
    if (!lastnl) nl
    return this
  }

  ** Print inline value
  This val(Obj? val)
  {
    if (val == null) return w("null")
    if (val is Str)  return quoted(val.toStr)
    if (val is Grid) return grid(val)
    if (val is Spec) return specTop(val)
    if (val is Dict) return dict(val)
    if (val is List) return list(val)
    if (val is Lib)  return lib(val)
    if (inMeta) return quoted(val.toStr)
    if (val is Ref) return ref(val)
    return w(val)
  }

  ** Print list
  This list(Obj?[] list)
  {
    bracket("[")
    list.each |v, i|
    {
      if (i > 0) w(", ")
      val(v)
    }
    bracket("]")
    return this
  }

  ** Print dict
  This dict(Dict dict)
  {
    bracket("{").pairs(dict).bracket("}")
  }

  ** Print dict pairs without brackets
  This pairs(Dict dict, Str[]? skip := null)
  {
    first := true
    dict.each |v, n|
    {
      if (skip != null && skip.contains(n)) return
      if (first) first = false
      else w(", ")
      w(n)
      if (isMarker(v)) return
      colon

      if (inMeta)
      {
        // express as Xeto values
        if (v === env.none) return w("None \"none\"")
        if (v === env.na) return w("NA \"na\"")
        if (v is Str) return quoted(v)
        t := env.specOf(v)
        if (t.isScalar) return w(t.qname).sp.quoted(v.toStr)
      }

      if (v is Spec) return w(v.toStr)
      val(v)
    }
    return this
  }

  ** Print ref
  This ref(Ref ref)
  {
    w("@").w(ref.id)
    if (ref.disVal != null) sp.quoted(ref.dis)
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Grid
//////////////////////////////////////////////////////////////////////////

  ** Print list
  This grid(Grid grid)
  {
    cols := grid.cols.dup

    id := cols.find { it.name == "id" }
    dis := cols.find { it.name == "dis" }
    cols.moveTo(id, 0)
    cols.moveTo(dis, -1)

    table := Str[][,]
    table.add(cols.map |c->Str| { c.dis })
    grid.each |row|
    {
      cells := Str[,]
      cells.capacity = cols.size
      cols.each |c|
      {
        val := row.val(c)
        if (val is Str)
        {
          cells.add(val)
        }
        else if (val is Ref)
        {
          ref := (Ref)val
          s := "@"+ref.id
          if (ref.disVal != null) s += " " + ref.disVal.toCode
          cells.add(s)
        }
        else
        {
          cells.add(row.dis(c.name))
        }
      }
      table.add(cells)
    }

    return this.table(table)
  }

//////////////////////////////////////////////////////////////////////////
// Table
//////////////////////////////////////////////////////////////////////////

  ** Print table
  This table(Str[][] cells)
  {
    if (cells.isEmpty) return this

    // compute col widths
    numCols := cells[0].size
    colWidths := Int[,].fill(0, numCols)
    cells.each |row|
    {
      row.each |cell, col|
      {
        colWidths[col] = colWidths[col].max(cell.size)
      }
    }

    // if total width exceeds terminal, first try to shrink down the biggest
    // ones; but don't strink first 2 which typically contain id, dis
    while (true)
    {
      total := 0
      colWidths.each |w| { total += w + 2 }
      if (total <= width) break
      maxi := colWidths.size-1
      colWidths.eachRange(2..-1) |w, i| { if (w > colWidths[maxi]) maxi = i }
      if (colWidths[maxi] < 16) break
      colWidths[maxi] = colWidths[maxi] - 1
    }

    // if total width still exceeds terminal, chop off last columns
    lastCol := numCols
    total := 0
    for (i := 0; i<numCols; ++i)
    {
      total += colWidths[i] + 2
      if (total > width) break
      lastCol = i
    }

    // clip rows to fit height
    numRows := cells.size
    maxRows := numRows //height - 4

    // output
    cells.each |row, rowIndex|
    {
      if (rowIndex >= maxRows) return
      isHeader := rowIndex == 0
      if (isHeader) color(theme.comment)
      row.each |cell, col|
      {
        if (col > lastCol) return
        str := cell.replace("\n", " ")
        colw := colWidths[col]
        if (str.size > colw) str = str[0..<(colw-2)] + ".."
        w(str).w(Str.spaces(colw - str.size + 2))
      }
      nl
      if (isHeader)
      {
        numCols.times |col|
        {
          if (col > lastCol) return
          colw := colWidths[col]
          colw.times { wc('-') }
          w("  ")
        }
        nl
        colorEnd(theme.comment)
      }
    }

    if (maxRows < numRows)
      warn("${numRows - maxRows} more rows; use {showall} to see all rows")

    return this
  }

//////////////////////////////////////////////////////////////////////////
// Spec
//////////////////////////////////////////////////////////////////////////

  ** Print data spec using current mode
  This lib(Lib lib)
  {
    print(lib.name)
    bracket(" {").nl
    indention++
    lib.types.each |t| { specTop(t).nl.nl }
    indention--
    bracket("}").nl
    return this
  }

  ** Print data spec using current mode
  This specTop(Spec spec)
  {
    mode := this.specMode
    if (mode === PrinterSpecMode.qname)
      return w(spec.qname)
    else
      return doc(spec, mode).w(spec.qname).colon.spec(spec, mode)
  }

  ** Print data spec with specific mode
  private This spec(Spec spec, PrinterSpecMode mode)
  {
    switch (mode)
    {
      case PrinterSpecMode.qname:      w(spec.qname)
      case PrinterSpecMode.effective:  specEffective(spec)
      default:                         specOwn(spec)
    }
    return this
  }

  ** Print only declared meta/slots
  private This specOwn(Spec spec)
  {
    base(spec).meta(spec.metaOwn).slots(spec.slotsOwn, PrinterSpecMode.own)
  }

  ** Print all effective meta/slots
  private This specEffective(Spec spec)
  {
    base(spec).meta(spec.metaOwn).slots(spec.slots, PrinterSpecMode.effective)
  }

  ** Print base inherited type with special handling for maybe/and/or
  private This base(Spec spec)
  {
    if (spec.isCompound)
    {
      symbol := spec.base.name == "And" ? "&" : "|"
      spec.ofs.each |x, i|
      {
        if (i > 0) sp.bracket(symbol).sp
        w(x.qname)
      }
    }
    else if (spec.base != null)
    {
      if (spec.isType)
        w(spec.base.qname)
      else
        w(spec.type.qname)
      if (spec.isMaybe) bracket("?")
    }
    return this
  }

  ** Spec meta data
  private This meta(Dict dict)
  {
    skip := ["doc", "ofs", "maybe"]
    show := dict.eachWhile |v, n|
    {
      if (skip.contains(n)) return null
      return "show"
    }
    if (show == null) return this

    inMeta = true
    sp.bracket("<").pairs(dict, skip).bracket(">")
    inMeta = false
    return this
  }

  ** Spec slots
  private This slots(SpecSlots slots, PrinterSpecMode mode)
  {
    if (slots.isEmpty) return this
    bracket(" {").nl
    indention++
    slots.each |slot|
    {
      doc(slot, mode)
      showName := !XetoUtil.isAutoName(slot.name)
      indent
      if (showName) w(slot.name)
      if (!isMarker(slot["val"]) && slot.base != null)
      {
        if (showName) w(": ")
        if (slot.base?.type === slot.base && !slot.isType)
        {
          base(slot)
          meta(slot.metaOwn)
        }
        else
        {
          spec(slot, mode)
        }
      }
      nl
    }
    indention--
    indent.bracket("}")
    return this
  }


  ** Print doc lines if showdoc option configured
  private This doc(Spec spec, PrinterSpecMode mode)
  {
    Dict meta := mode === PrinterSpecMode.own ? spec.metaOwn : spec.meta
    doc := (meta.get("doc") as Str)?.trimToNull
    if (doc == null || !showdoc) return this

    doc.splitLines.each |line, i|
    {
      indent.comment("// $line").nl
    }
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Xeto Instance
//////////////////////////////////////////////////////////////////////////

  ** Pretty print instance data in Xeto text format
  This xetoTop(Obj x)
  {
    xeto(x, true)
  }

  ** Pretty print instance data in Xeto text format
  This xeto(Obj x, Bool top := false)
  {
    spec := env.specOf(x)
    if (spec.isScalar) return xetoScalar(spec, x)
    if (x is Dict) return xetoDict(spec, x, top)
    if (x is List) return xetoList(spec, x)
    throw ArgErr("Not xeto type: $x.typeof")
  }

  ** Print scalar in Xeto text format
  private This xetoScalar(Spec spec, Obj x)
  {
    if (spec === env.sys.ref)
    {
      ref := (Ref)x
      w("@").w(ref.id)
      if (ref.disVal != null) sp.w(ref.disVal.toCode)
      return this
    }

    if (spec !== env.sys.str) qname(spec).sp
    return w(x.toStr.toCode)
  }

  ** Print dict in Xeto text format
  private This xetoDict(Spec spec, Dict x, Bool top)
  {
    id := x["id"] as Ref
    if (top)
    {
      if (id != null) w("@").w(id.id).colon
    }

    qname(spec).sp
    if (x.isEmpty) return bracket("{}")
    bracket("{").nl
    indention++
    if (id != null && !top) indent.w("id").colon.xeto(id).nl
    x.each |v, n|
    {
      if (n == "id" || n == "spec") return
      indent
      w(n)
      if (v === env.marker) return nl
      colon.xeto(v).nl
    }
    indention--
    indent.bracket("}")
    return this
  }

  ** Print list in Xeto text format
  private This xetoList(Spec spec, Obj[] x)
  {
    if (x.isEmpty) return w("List").sp.bracket("{}")
    w("List").sp.bracket("{").nl
    indention++
    x.each |v, i|
    {
      indent
      xeto(v).nl
    }
    indention--
    bracket("}")
    return this
  }

//////////////////////////////////////////////////////////////////////////
// JSON
//////////////////////////////////////////////////////////////////////////

  ** Pretty print haystack data as JSON
  This json(Obj? val)
  {
    if (val is Dict) return jsonDict(val)
    if (val is List) return jsonList(val)
    return jsonScalar(val)
  }

  private This jsonDict(Dict dict)
  {
    bracket("{").nl
    indention++
    first := true
    dict.each |x, n|
    {
      if (first) first = false
      else comma.nl
      indent.quoted(n).colon.json(x)
    }
    indention--
    nl.indent.bracket("}")
    return this
  }

  private This jsonList(Obj?[] list)
  {
    bracket("[").nl
    indention++
    list.each |x, i|
    {
      indent.json(x)
      if (i + 1 < list.size) comma
      nl
    }
    indention--
    indent.bracket("]")
    return this
  }

  private This jsonScalar(Obj? val)
  {
    if (val == null) return w("null")
    if (val is Bool) return w(val.toStr)
    return quoted(val.toStr)
  }

//////////////////////////////////////////////////////////////////////////
// Theme Utils
//////////////////////////////////////////////////////////////////////////

  ** Enter color section which should be constant from PrinterTheme
  This color(Str? color)
  {
    if (color != null) w(color)
    return this
  }

  ** Exit colored section
  This colorEnd(Str? color)
  {
    if (color != null) w(PrinterTheme.reset)
    return this
  }

  ** Print quoted string in theme color
  This quoted(Str str, Str quote := "\"")
  {
    color(theme.str)
    w(quote)
    str.each |char|
    {
      if (char <= 0x7f || !escUnicode)
      {
        switch (char)
        {
          case '\b': wc('\\').wc('b')
          case '\f': wc('\\').wc('f')
          case '\n': wc('\\').wc('n')
          case '\r': wc('\\').wc('r')
          case '\t': wc('\\').wc('t')
          case '\\': wc('\\').wc('\\')
          case '"':  wc('\\').wc('"')
          default: wc(char)
        }
      }
      else
      {
        wc('\\').wc('u').w(char.toHex(4))
      }
    }
    w(quote)
    colorEnd(theme.str)
    return this
  }

  ** Print bracket such as "{}" in theme color
  This bracket(Str symbol)
  {
    color(theme.bracket).w(symbol).colorEnd(theme.bracket)
  }

  ** Colon and space (uses bracket color for now)
  This colon()
  {
    bracket(":").sp
  }

  ** Comma  (uses bracket color for now)
  This comma()
  {
    bracket(",")
  }

  ** Print comment string in theme color
  This comment(Str str)
  {
    color(theme.comment).w(str).colorEnd(theme.comment)
  }

  ** Print in warning theme color
  This warn(Str str)
  {
    color(theme.warn).w(str).colorEnd(theme.warn)
  }

//////////////////////////////////////////////////////////////////////////
// OutStream Utils
//////////////////////////////////////////////////////////////////////////

  This qname(Spec spec)
  {
    spec.lib === env.sysLib ? w(spec.name) : w(spec.qname)
  }

  This w(Obj obj)
  {
    str := obj.toStr
    lastnl = str.endsWith("\n")
    out.print(str)
    return this
  }

  This wc(Int char)
  {
    lastnl = false
    out.writeChar(char)
    return this
  }

  This nl()
  {
    lastnl = true
    out.printLine
    return this
  }

  This sp() { wc(' ') }

  This indent() { w(Str.spaces(indention*2)) }

//////////////////////////////////////////////////////////////////////////
// Data Utils
//////////////////////////////////////////////////////////////////////////

  private Bool isMarker(Obj? val) { val === env.marker }

//////////////////////////////////////////////////////////////////////////
// Options
//////////////////////////////////////////////////////////////////////////

  Obj? opt(Str name, Obj? def := null)
  {
    opts.get(name, def)
  }

  Bool optBool(Str name, Bool def)
  {
    v := opt(name)
    if (v == env.marker) return true
    if (v is Bool) return v
    return def
  }

  Int optInt(Str name, Int def)
  {
    v := opt(name, def)
    if (v is Int) return v
    if (v is Number) return ((Number)v).toInt
    return def
  }

  PrinterSpecMode optSpecMode()
  {
    v := opt("spec", null)
    if (v != null) return PrinterSpecMode.fromStr(v)
    v = opts.eachWhile |ignore, n| { PrinterSpecMode.fromStr(n, false) }
    if (v != null) return v
    return PrinterSpecMode.auto
  }

  Int terminalWidth()
  {
    if (isStdout) return 100_000
    try
    {
      jline := Type.find("[java]jline::TerminalFactory", false)
      if (jline != null) return jline.method("get").call->getWidth
    }
    catch (Err e) {} // ignore
    return 80
  }

  Int terminalHeight()
  {
    if (isStdout) return 100_000
    try
    {
      jline := Type.find("[java]jline::TerminalFactory", false)
      if (jline != null) return jline.method("get").call->getHeight
    }
    catch (Err e) {} // ignore
    return 50
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const MEnv env                  // environment
  const Bool isStdout             // are we printing to stdout
  const Dict opts                 // options
  const Bool escUnicode           // escape unicode above 0x7f
  const PrinterSpecMode specMode  // how to print specs
  const Bool showdoc              // print documentation
  const Int width                 // terminal width
  const Int height                // terminal height
  const PrinterTheme theme        // syntax color coding
  private OutStream out           // output stream
  private Int indention           // current level of indentation
  private Bool lastnl             // was last char a newline
  private Bool inMeta             // in spec meta
}

**************************************************************************
** PrinterSpecMode
**************************************************************************

@Js
enum class PrinterSpecMode
{
  auto, qname, own, effective
}

**************************************************************************
** PrinterTheme
**************************************************************************

@Js
const class PrinterTheme
{
  static const Str reset  := "\u001B[0m"
  static const Str black  := "\u001B[30m"
  static const Str red    := "\u001B[31m"
  static const Str green  := "\u001B[32m"
  static const Str yellow := "\u001B[33m"
  static const Str blue   := "\u001B[34m"
  static const Str purple := "\u001B[35m"
  static const Str cyan   := "\u001B[36m"
  static const Str white  := "\u001B[37m"

  static const PrinterTheme none := make {}

  static const AtomicRef configuredRef := AtomicRef()

  static PrinterTheme configured()
  {
    theme := configuredRef.val as PrinterTheme
    if (theme == null)
      configuredRef.val = theme = loadConfigured
    return theme
  }

  private static PrinterTheme loadConfigured()
  {
    try
    {
      // load from environment variable:
      // export DATA_PRINT_THEME="bracket:red, str:cyan, comment:green, warn:yellow"
      var := Env.cur.vars["DATA_PRINT_THEME"]
      if (var == null) return none

      // variable should be formatted as symbol:color, str:color, comment:color
      toks := var.split(',')
      map := Str:Str[:]
      toks.each |tok|
      {
        pair := tok.split(':')
        if (pair.size != 2) return
        key := pair[0]
        color := PrinterTheme#.field(pair[1], false)?.get(null)
        map.addNotNull(key, color)
      }

      // construct
      return make {
        it.bracket = map["bracket"]
        it.str     = map["str"]
        it.comment = map["comment"]
        it.warn    = map["warn"]
      }
    }
    catch (Err e)
    {
      echo("ERROR: Cannot load pog theme")
      e.trace
      return none
    }
  }

  new make(|This| f) { f(this) }

  const Str? bracket
  const Str? str
  const Str? comment
  const Str? warn
}