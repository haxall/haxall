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
** All value encoding flows through `val` which always clips large
** data; the public write methods are low-level utils shared with
** subclasses such as AiToolWriter.
**
@Js
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

  ** Format a data value to its LLM text encoding.  Each type has one
  ** consistent encoding which always clips large data so one value
  ** cannot flood a conversation:
  **  - scalar: toStr truncated to truncate chars
  **  - dict: trio
  **  - list: markdown bullets or trio dicts; first maxItems items
  **  - grid: summary line + zinc; first maxRows rows
  This val(Obj? x)
  {
    if (x == null) return w("null")
    if (x is Grid) return grid(x)
    if (x is Dict) return dict(x)
    if (x is List) return list(x)
    return scalar(x)
  }

  ** Format error with message and stack trace
  This err(Err e)
  {
    w("ERROR: $e.toStr").nl
    e.trace(out)
    return this
  }

  ** Scalar as toStr truncated to truncate chars
  private This scalar(Obj x)
  {
    wtruncated(x)
  }

  ** Dict as trio
  private This dict(Dict x)
  {
    if (x.isEmpty) return w("{}").nl
    TrioWriter(out).writeDict(x)
    return this
  }

  ** List as trio dicts or markdown bullets; over maxItems write
  ** only the first items followed by count of those clipped
  private This list(Obj?[] x)
  {
    if (x.isEmpty) return w("[]")

    more := x.size - maxItems
    if (more > 0) x = x[0..<maxItems]

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
    }
    else
    {
      x.each |v, i|
      {
        if (i > 0) tab
        w("- ").indent.val(v).unindent.nl
      }
    }

    if (more > 0) w("... ").w(more).w(" more items").nl
    return this
  }

  ** Grid as summary line + zinc; over maxRows write only the first
  ** rows followed by count of those clipped and paging hint
  private This grid(Grid x)
  {
    // summary line: Grid 3 cols x 150 rows
    w("Grid ").w(x.cols.size).w(" cols x ").w(x.size).w(" rows").nl

    // zinc rows: all if under maxRows, else first maxRows + paging hint
    more := x.size - maxRows
    if (more <= 0) { ZincWriter(out).writeGrid(x); return this }
    ZincWriter(out).writeGrid(Etc.makeDictsGrid(x.meta, x.toRows[0..<maxRows]))
    return w("... $more more rows; page with [${maxRows}..${maxRows*2-1}] or refine the query").nl
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

  ** Write truncated string default length of truncate const
  This wtruncated(Obj x, Int limit := truncate) { w(x.toStr.truncate(limit, "..")) }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** Max chars for a scalar string before truncation
  static const Int truncate := 4096

  ** Max grid rows written before clipping
  static const Int maxRows := 100

  ** Max list items written before clipping
  static const Int maxItems := 100

  private StrBuf? buf
  protected OutStream out
  private Int indentation
  private Bool sol := true
}

