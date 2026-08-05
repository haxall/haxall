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

  new make(MNamespace ns, OutStream out, Spec? rootSpec := null, Dict opts := Etc.dict0)
  {
    this.ns         = ns
    this.out        = out
    this.rootSpec   = rootSpec
    this.xutil      = XetoJsonUtil(ns)
    this.box        = XetoUtil.optBox(opts)
    this.pretty     = XetoUtil.optBool(opts, "pretty", false)
    this.escUnicode = XetoUtil.optBool(opts, "escapeUnicode", false)
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  Void writeVal(Obj? val)
  {
    doVal(val, rootSpec)
  }

  private This doVal(Obj? val, Spec? spec)
  {
    if (val is Dict) return writeDict(val, spec)
    if (val is List) return writeList(val, spec)
    if (val is Grid) return writeGrid(val)
    return writeScalar(val, spec)
  }

  private This writeDict(Dict dict, Spec? context)
  {
    spec := xutil.dictSpec(dict, context, false)
    wc('{').nl
    indentation++
    first := true
    dict.each |x, n|
    {
      if (first) first = false
      else wc(',').nl
      indent.quoted(n).wc(':')

      // spec and of are structural refs; they are never boxed
      if (isStructuralTag(n) && (x is Ref || x is Str))
        quoted(encodeScalar(x))
      else
        doVal(x, xutil.member(spec, n))
    }
    indentation--
    nl.indent.wc('}')
    return this
  }

  private This writeList(Obj?[] list, Spec? spec)
  {
    of := xutil.listOf(spec)
    wc('[').nl
    indentation++
    first := true
    list.each |x|
    {
      if (first) first = false
      else wc(',').nl
      indent.doVal(x, of)
    }
    indentation--
    nl.indent.wc(']')
    return this
  }

  private This writeGrid(Grid grid)
  {
    wc('{').nl
    indentation++

    // spec
    specRef := XetoUtil.gridSpecRef(grid)
    indent.quoted("spec").wc(':').quoted(specRef.id)
    wc(',').nl

    // meta; the grid spec is emitted above, not repeated inside meta
    meta := dictExclude(grid.meta, "spec")
    if (!meta.isEmpty)
    {
      indent.quoted("meta").wc(':').writeDict(meta, null)
      wc(',').nl
    }

    // default row spec: the instance 'of' then the schema 'of'
    rowSpec := xutil.rowSpec(XetoUtil.gridOfSpecRef(grid),
                             xutil.resolve(specRef, false), false)

    // cols
    indent.quoted("cols").wc(':')
    wc('[').nl
    indentation++
    first := true
    grid.cols.each |c|
    {
      if (first) first = false
      else wc(',').nl
      indent.writeCol(c)
    }
    indentation--
    nl.indent.wc(']')
    wc(',').nl

    // rows
    indent.quoted("rows").wc(':')
    wc('[').nl
    indentation++
    first = true
    grid.each |row|
    {
      if (first) first = false
      else wc(',').nl
      indent.doVal(row, rowSpec)
    }
    indentation--
    nl.indent.wc(']')

    // done
    indentation--
    nl.indent.wc('}')
    return this
  }

  ** Wire form of a column: 'of' is structural and sits beside 'name' rather
  ** than inside meta.  Written directly because 'name' and 'of' describe the
  ** envelope and must stay plain strings at every box mode.
  private This writeCol(Col c)
  {
    wc('{').nl
    indentation++
    indent.quoted("name").wc(':').quoted(c.name)

    of := XetoUtil.gridColSpecRef(c)
    if (of != null)
    {
      wc(',').nl
      indent.quoted("of").wc(':').quoted(of.id)
    }

    meta := dictExclude(c.meta, "of")
    if (!meta.isEmpty)
    {
      wc(',').nl
      indent.quoted("meta").wc(':').writeDict(meta, null)
    }

    indentation--
    nl.indent.wc('}')
    return this
  }

  ** Dict minus one tag, preserving tag order.  'Etc.dictRemove' rebuilds
  ** through an unordered map, which would make the output non-idempotent.
  private Dict dictExclude(Dict d, Str name)
  {
    if (d.missing(name)) return d
    acc := Str:Obj[:]
    acc.ordered = true
    d.each |v, n| { if (n != name) acc[n] = v }
    return Etc.dictFromMap(acc)
  }

//////////////////////////////////////////////////////////////////////////
// Scalars
//////////////////////////////////////////////////////////////////////////

  private This writeScalar(Obj? val, Spec? spec)
  {
    if (val == null) return w("null")

    bspec := boxSpec(val, spec)
    if (bspec != null) return writeBox(val, bspec)

    return writePlain(val)
  }

  ** The spec to box this value with, or null to write it plainly.  Under
  ** 'auto' a value is boxed only when its plain form would not survive the
  ** reader's ladder in this position.
  private Spec? boxSpec(Obj val, Spec? expected)
  {
    if (box.isNone) return null
    if (box.isAuto && xutil.plainRoundTrips(val, expected)) return null
    return ns.specOf(val, false)
  }

  ** Rule 1 wire form.  The members are structural and are written directly,
  ** so a box never nests inside a box.
  private This writeBox(Obj val, Spec spec)
  {
    wc('{').nl
    indentation++
    indent.quoted("val").wc(':').quoted(encodeScalar(val))
    wc(',').nl
    indent.quoted("spec").wc(':').quoted(spec.qname)

    // a box is the only place a Ref's display string can travel
    dis := (val as Ref)?.disVal
    if (dis != null)
    {
      wc(',').nl
      indent.quoted("dis").wc(':').quoted(dis)
    }

    indentation--
    nl.indent.wc('}')
    return this
  }

  private This writePlain(Obj val)
  {
    if (val is Bool)   return w(val.toStr)
    if (val is Int)    return writeInt(val)
    if (val is Number) return writeNumber(val)
    if (val is Float)  return writeFloat(val)
    return quoted(encodeScalar(val))
  }

  ** Is the tag name one of the reserved structural tags
  private Bool isStructuralTag(Str n)
  {
    n == "spec" || n == "of"
  }

  ** Encode a scalar to its Xeto string form via the value's own binding, so
  ** that a plain and a boxed encoding are identical text.
  private Str encodeScalar(Obj val)
  {
    spec := ns.specOf(val, false)
    if (spec == null) return val.toStr
    binding := spec.binding
    if (!binding.isScalar) return val.toStr
    return binding.encodeScalar(val)
  }

  private This writeInt(Int i)
  {
    w(i.toStr)
  }

  private This writeFloat(Float f)
  {
    // "special" float values are quoted: "-INF", "INF", "NaN"
    s := f.toStr
    if (s.size >= 3 && (s[0] == 'I' || s[0] == 'N' || s[1] == 'I'))
      return quoted(s)
    else
      return w(s)
  }

  private This writeNumber(Number n)
  {
    // unitless might be float literal, but units must be quoted
    if (n.unit == null)
    {
      if (n.isInt)
        return writeInt(n.toInt)
      else
        return writeFloat(n.toFloat)
    }
    else
    {
      return quoted(n.toStr)
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

  private const MNamespace ns
  private const JsonBoxMode box
  private const Bool escUnicode
  private const Bool pretty
  private Spec? rootSpec
  private XetoJsonUtil xutil
  private OutStream out
  private Int indentation
}

