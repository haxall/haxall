//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Sep 2009  Brian Frank  Creation
//

using haystack

**
** Literal
**
@NoDoc
@Js
const class Literal : Expr
{
  static Literal bool(Bool val) { val ? trueVal : falseVal }
  const static Literal trueVal   := Literal(true)
  const static Literal falseVal  := Literal(false)
  const static Literal nullVal   := Literal(null)
  const static Literal markerVal := Literal(Marker.val)
  const static Literal removeVal := Literal(Remove.val)

  static Literal wrap(Obj? val)
  {
    if (val == null) return nullVal
    if (val.isImmutable) return make(val)
    return UnsafeLiteral(val)
  }

  new make(Obj? val) { this.val = val }

  override ExprType type() { ExprType.literal }

  override Loc loc() { Loc.unknown }

  const Obj? val

  override Bool isConst() { true }

  override Obj? constVal() { val }

  override Obj? eval(AxonContext cx) { val }

  override Void walk(|Str key, Obj? val| f) { f("val", val) }

  override Printer print(Printer out) { out.val(val) }
}

**************************************************************************
** UnsafeLiteral
**************************************************************************

@Js
internal const class UnsafeLiteral : Literal
{
  new make(Obj? val) : super(Unsafe(val)) {}
  override Obj? eval(AxonContext cx) { ((Unsafe)val).val }
}

**************************************************************************
** FilterExpr
**************************************************************************

@Js
internal const class FilterExpr : Expr
{
  new make(Filter filter) { this.filter = filter }

  override ExprType type() { ExprType.filter }

  override Loc loc() { Loc.unknown }

  const Filter filter

  override Obj? eval(AxonContext cx) { filter }

  override Void walk(|Str key, Obj? val| f)
  {
    f("filter", filter.toStr)
  }

  override Printer print(Printer out)
  {
    out.w("parseFilter(").w(filter.toStr.toCode).w(")")
  }
}

**************************************************************************
** ListExpr
**************************************************************************

@Js
internal const  class ListExpr : Expr
{
  const static ListExpr empty := make(Expr#.emptyList, true)

  new make(Expr[] vals, Bool allValsConst)
  {
    this.vals = vals
    if (allValsConst)
      this.constValRef = vals.map |v->Obj?| { v.constVal }
  }

  override ExprType type() { ExprType.list }

  override Loc loc() { vals.isEmpty ? Loc.unknown : vals.first.loc  }

  const Expr[] vals

  override Bool isConst() { constValRef != null }

  override Obj? constVal() { constValRef ?: super.constVal }

  private const Obj?[]? constValRef

  override Obj? eval(AxonContext cx)
  {
    if (constValRef != null) return constValRef
    return vals.map |expr->Obj?| { expr.eval(cx) }
  }

  override Void walk(|Str key, Obj? val| f) { f("vals", vals) }

  override Printer print(Printer out)
  {
    out.wc('[')
    vals.each |val, i|
    {
      if (i > 0) out.comma
      val.print(out)
    }
    return out.wc(']')
  }
}

**************************************************************************
** DictExpr
**************************************************************************

@Js
internal const class DictExpr : Expr
{
  const static DictExpr empty := make(Loc.unknown, Str#.emptyList, Expr#.emptyList, true)

  new make(Loc loc, Str[] names, Expr[] vals, Bool allValsConst)
  {
    this.loc   = loc
    this.names = names
    this.vals  = vals

    // check if we can optimize this to a fixed const value
    if (allValsConst)
    {
      tags := Str:Obj?[:]
      tags.ordered = true
      names.each |name, i| { tags[name] = vals[i].constVal }
      constValRef = Etc.makeDict(tags)
    }
  }

  override ExprType type() { ExprType.dict }

  override const Loc loc

  const Str[] names

  const Expr[] vals

  override Bool isConst() { constValRef != null }

  override Obj? constVal() { constValRef ?: super.constVal }

  private const Dict? constValRef

  override Obj? eval(AxonContext cx)
  {
    if (constValRef != null) return constValRef
    tags := Str:Obj?[:]
    tags.ordered = true
    names.each |name, i|
    {
      val := vals[i].eval(cx)
      tags[name] = val
    }
    return Etc.makeDict(tags)
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("names", names)
    f("vals",  vals)
  }

  override Printer print(Printer out)
  {
    out.wc('{')
    names.each |n, i|
    {
      if (i > 0) out.comma
      if (Etc.isTagName(n)) out.w(n); else out.w(n.toCode)
      val := vals[i]
      if (!val.isMarker) out.wc(':').expr(val)
    }
    return out.wc('}')
  }
}

**************************************************************************
** RangeExpr
**************************************************************************

@Js
internal const class RangeExpr : Expr
{
  new make(Expr start, Expr end) { this.start = start; this.end = end }

  override ExprType type() { ExprType.range }

  override Loc loc() { start.loc  }

  const Expr start

  const Expr end

  override Obj? eval(AxonContext cx)
  {
    s := start.eval(cx)
    e := end.eval(cx)
    if (s is Date && e is Date) return DateSpan.make(s, e)
    return ObjRange(s, e)
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("start", start)
    f("end",   end)
  }

  override Printer print(Printer out)
  {
    out.atomicStart.atomic(start).w("..").atomic(end).atomicEnd
  }
}

