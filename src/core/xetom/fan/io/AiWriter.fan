//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 May 2026  Brian Frank  Creation
//

using xeto
using haystack

**
** AiWriter formats values into text optimized for AI/LLM consumption.
**
class AiWriter
{
  ** Construct with out stream or if null to StrBuf
  new make(OutStream? out := null)
  {
    if (out != null)
    {
      this.out = out
    }
    else
    {
      this.buf = StrBuf(1024)
      this.out = buf.out
    }
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  ** Format data value
  This val(Obj? x)
  {
    if (x == null) return w("null")
    if (x is Grid) return grid(x)
    if (x is Dict) return dict(x)
    if (x is List) return list(x)
    return scalar(x)
  }

  ** Scalar
  This scalar(Obj x)
  {
    wtruncated(x)
  }

  ** Format grid as zinc
  This grid(Grid x)
  {
    ZincWriter(out).writeGrid(x)
    return this
  }

  ** Format grid summary as one-liner with col/row counts and col names
  This gridSummary(Grid x)
  {
    w("Grid ").w(x.cols.size).w(" cols x ").w(x.size).w(" rows")
    w(" cols(")
    limit := x.cols.size.min(5)
    for (i := 0; i < limit; ++i)
    {
      if (i > 0) w(", ")
      w(x.cols[i].name)
    }
    more := x.cols.size - limit
    if (more > 0) w(", ").w(more).w(" more")
    w(")")
    return this
  }

  ** Format grid preview with first N rows
  This gridPreview(Grid x, Int maxRows := 5)
  {
    gridSummary(x).nl
    if (x.size <= maxRows) return grid(x)
    rows := x.toRows
    grid(Etc.makeDictsGrid(x.meta, rows[0..<maxRows]))
    w("... ").w(x.size - maxRows).w(" more rows").nl
    return this
  }

  ** Format dict as trio
  This dict(Dict x)
  {
    if (x.isEmpty) return w("{}").nl
    TrioWriter(out).writeDict(x)
    return this
  }

  ** Format list based on value types as markdown list or trio
  This list(Obj?[] x)
  {
    if (x.isEmpty) return w("[]")

    dicts := x.all { it is Dict || it == null }
    if (dicts)
    {
      x.each |Dict? d, i|
      {
        if (i > 0) w("---").nl
        if (d == null) w("null").nl
        else if (d.isEmpty) w("{}").nl
        else TrioWriter(out).writeDict(d)
      }
      return this
    }

    x.each |v, i|
    {
      if (i > 0) tab
      w("- ").indent.val(v).unindent.nl
    }
    return this
  }

  ** Error
  This err(Err e)
  {
    w("ERROR: $e.toStr").nl
    e.trace(out)
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Encode buf to string
  Str bufToStr() { buf?.toStr ?: throw Err("Created with explicit out") }

  ** Write string
  This w(Obj obj) { out.print(obj); sol = false; return this }

  ** Write one char
  This wc(Int char) { out.writeChar(char); sol = false;  return this }

  ** Write space
  This sp() { wc(' ') }

  ** Write newline
  This nl() { out.printLine; sol = true; return this }

  ** Write start of line indentation spaces
  This tab() { w(Str.spaces(indentation*2)) }

  ** Increment indentation by one level
  This indent() { ++indentation; return this }

  ** Decrement indentation by one level
  This unindent() { --indentation; return this }

  ** Flush underlying output stream
  This flush() { out.flush; return this }

  ** Write truncated string default length of 64
  This wtruncated(Obj x, Int limit := truncate) { w(x.toStr.truncate(limit, "..")) }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** Default length to truncate data strings
  static const Int truncate := 100

  private StrBuf? buf
  protected OutStream out
  private Int indentation
  private Bool sol := true
}

