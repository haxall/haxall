//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Jan 2026  Brian Frank  Creation
//

using xeto
using haystack

**
** XetoJsonWriter
**
@Js
class XetoJsonWriter
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(OutStream out, Dict opts)
  {
    this.out        = out
    this.pretty     = XetoUtil.optBool(opts, "pretty", false)
    this.escUnicode = XetoUtil.optBool(opts, "escapeUnicode", false)
  }

  internal new makeExport(OutStream out)
  {
    this.out = out
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  Void writeVal(Obj? val)
  {
    if (val is Dict) return writeDict(val)
    if (val is List) return writeList(val)
    if (val is Grid) return writeGrid(val)
    return writeScalar(val)
  }

  private Void writeDict(Dict dict)
  {
    wc('{').nl
    indentation++
    first := true
    dict.each |x, n|
    {
      if (first) first = false
      else wc(',').nl
      indent.quoted(n).wc(':').writeVal(x)
    }
    indentation--
    nl.indent.wc('}')
    return this
  }

  private This writeList(Obj?[] list)
  {
    wc('[').nl
    indentation++
    first := true
    list.each |x, i|
    {
      if (first) first = false
      else wc(',').nl
      indent.writeVal(x)
    }
    indentation--
    nl.indent.wc(']')
    return this
  }

  private Void writeGrid(Grid grid)
  {
    wc('{').nl
    indentation++

    //--------------------------------------
    // spec

    indent.quoted("spec").wc(':').quoted("sys::Grid")
    wc(',').nl

    //--------------------------------------
    // meta

    indent.quoted("meta").wc(':')
    wc('{').nl
    indentation++
    first := true
    if (!grid.meta.isEmpty)
    {
      first = false
      indent.quoted("#grid").wc(':').writeVal(grid.meta)
    }
    grid.cols.each |c|
    {
      if (!c.meta.isEmpty)
      {
        if (first) first = false
        else wc(',').nl
        indent.quoted(c.name).wc(':').writeVal(c.meta)
      }
    }
    indentation--
    nl.indent.wc('}')
    wc(',').nl

    //--------------------------------------
    // rows

    indent.quoted("rows").wc(':')
    wc('[').nl
    indentation++
    first = true
    grid.each |row|
    {
      if (first) first = false
      else wc(',').nl
      indent.writeVal(row)
    }
    indentation--
    nl.indent.wc(']')

    //--------------------------------------
    // done

    indentation--
    nl.indent.wc('}')
    return this
  }

  private Void writeScalar(Obj? val)
  {
    if (val == null)   return w("null")
    if (val is Bool)   return w(val.toStr)
    if (val is Int)    return writeInt(val)
    if (val is Number) return writeNumber(val)
    if (val is Float)  return writeFloat(val)
    return quoted(val.toStr)
  }

  private Void writeInt(Int i)
  {
    w(i.toStr)
  }

  private Void writeFloat(Float f)
  {
    // "special" float values are quoted: "-INF", "INF", "NaN"
    s := f.toStr
    if (s.size >= 3 && (s[0] == 'I' || s[0] == 'N' || s[1] == 'I'))
      quoted(s)
    else
      return w(s)
  }

  private Void writeNumber(Number n)
  {
    // unitless might be float literal, but units must be quoted
    if (n.unit == null)
    {
      if (n.isInt)
        writeInt(n.toInt)
      else
        writeFloat(n.toFloat)
    }
    else
    {
      quoted(n.toStr)
    }
  }

  This quoted(Str str)
  {
    wc('"')
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
    wc('"')
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  This indent()
  {
    if (pretty) w(Str.spaces(indentation*2))
    return this
  }

  private This wc(Int char)
  {
    out.writeChar(char)
    return this
  }

  private This w(Str x)
  {
    out.print(x)
    return this
  }

  private This nl()
  {
    if (pretty) out.printLine
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const Bool escUnicode
  private const Bool pretty
  private OutStream out
  private Int indentation
}

