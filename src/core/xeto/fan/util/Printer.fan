//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Dec 2022  Brian Frank  Creation
//

using concurrent
using util
using data
using haystack

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
  new make(DataEnv env, OutStream out, DataDict opts)
  {
    this.env        = env
    this.out        = out
    this.opts       = opts
    this.escUnicode = optBool("escapeUnicode", false)
    this.showdoc    = optBool("showdoc", true)
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
    val(v)
    if (!lastnl) nl
    return this
  }

  ** Print inline value
  This val(Obj? val)
  {
    if (val == null) return w("null")
    if (val is Str) return quoted(val.toStr)
    if (val is Grid) return grid(val)
    if (val is DataSpec) return spec(val, null)
    if (val is Dict) return dict(val)
    if (val is List) return list(val)
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
  This dict(DataDict dict)
  {
    bracket("{").pairs(dict).bracket("}")
  }

  ** Print dict pairs without brackets
  This pairs(DataDict dict, Str[]? skip := null)
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
      if (v is DataType)
        w(v.toStr)
      else if (v is DataSpec)
        spec(v, null, false)
      else
        val(v)
    }
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
// Data Type System
//////////////////////////////////////////////////////////////////////////

  ** Print data type and its slots
  This spec(DataSpec spec, Str? name, Bool comments := true)
  {
    if (name == null)
    {
      if (spec is DataLib) name = ((DataLib)spec).qname
      else if (spec is DataType) name = ((DataType)spec).name
    }

    if (comments) doc(spec["doc"])
    if (name != null) indent.w(name).colon
    w(spec.type.qname)
    meta(spec.own)
    if (!spec.slotsOwn.isEmpty)
    {
      bracket(" {").nl
      indention++
      spec.slotsOwn.each |s|
      {
        if (indention == 1) nl
        this.spec(s, s.name)
      }
      indention--
      indent.bracket("}")
    }
//    if (spec.val != null && !isMarker(spec.val)) sp.quoted(spec.val.toStr)
    if (comments) nl
    return this
  }

  ** Meta data
  This meta(DataDict dict)
  {
    show := dict.eachWhile |v, n|
    {
      if (n == "doc") return null
      return "yes"
    }
    if (show == null) return this
    return sp.bracket("<").pairs(dict, ["doc"]).bracket(">")
  }


  ** Print doc lines if showdoc option configured
  private Void doc(Str? doc)
  {
    if (doc == null || doc.isEmpty) return
    if (!showdoc) return

    doc.splitLines.each |line, i|
    {
      indent.comment("// $line").nl
    }
  }

//////////////////////////////////////////////////////////////////////////
// JSON AST
//////////////////////////////////////////////////////////////////////////

  ** Print the AST tree for the given spec
  This printJsonAst(DataSpec spec)
  {
    bracket("{").nl
    indention++
    type := spec.type
    if (type === spec)
    {
      if (type.base != null) indent.quoted("type").colon.quoted(type.base.qname).nl
    }
    spec.each |v, n| { indent.quoted(n).colon.json(v).nl }
//    if (spec.val != null) indent.quoted("val").colon.quoted(spec.val.toStr).nl
    slots := spec.slotsOwn
    if (!slots.isEmpty)
    {
      indent.quoted("slots").colon.bracket("{").nl
      indention++
      slots.each |slot|
      {
        indent.quoted(slot.name).colon
        printJsonAst(slot)
      }
      indention--
      indent.bracket("}").nl
    }
    indention--
    indent.bracket("}").nl
    return this
  }

  This json(Obj? val)
  {
    if (val == null) return w("null")
    if (val is Bool) return w(val.toStr)
    if (val is List) return jsonList(val)
    return quoted(val.toStr)
  }

  This jsonList(Obj?[] list)
  {
    bracket("[")
    list.each |x, i|
    {
      if (i > 0) w(", ")
      json(x)
    }
    return bracket("]")
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

  Obj? opt(Str name, Obj? def := null) { opts.get(name, def) }

  Bool optBool(Str name, Bool def) { opt(name, def) as Bool ?: def }

  Int optInt(Str name, Int def) { opt(name, def) as Int ?: def }

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

  private OutStream out        // output stream
  private Int indention        // current level of indentation
  private Bool lastnl          // was last char a newline
  const DataEnv env            // environment
  const Bool isStdout          // are we printing to stdout
  const DataDict opts          // options
  const Bool escUnicode        // escape unicode above 0x7f
  const Bool showdoc           // print documentation
  const Int width              // terminal width
  const Int height             // terminal height
  const PrinterTheme theme     // syntax color coding
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