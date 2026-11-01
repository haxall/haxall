//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Oct 2026  Brian Frank  Creation
//

using util
using xeto
using xetom::XetoUtil
using haystack

**
** Pattern is the AST node for a switch case pattern.  Patterns are
** not evaluated, they test if a subject matches.
**
@NoDoc @Js
const abstract class Pattern : Expr
{
  new make(FileLoc loc) { this.loc = loc }

  override const FileLoc loc

  ** Return if subject matches this pattern
  abstract Bool match(AxonContext cx, Obj? subject)

  override final Obj? eval(AxonContext cx) { throw UnsupportedErr("Pattern cannot be evaluated: $type") }

  ** Map subject to its enum item spec or null if not a valid key
  static Spec? enumItem(Spec enum, Obj? subject)
  {
    key := XetoUtil.enumKey(subject)
    return key == null ? null : enum.enum.spec(key, false)
  }
}

**************************************************************************
** LiteralPattern
**************************************************************************

**
** Matches when subject equals literal using Axon equality, or when
** literal is a DateSpan such as a month and the subject is a Date
** within the span
**
@NoDoc @Js
const class LiteralPattern : Pattern
{
  new make(FileLoc loc, Obj? literal) : super(loc) { this.literal = literal }

  override ExprType type() { ExprType.literalPattern }

  const Obj? literal

  override Bool match(AxonContext cx, Obj? subject)
  {
    if (subject is Date && literal is DateSpan) return ((DateSpan)literal).contains(subject)
    return Eq.eqVals(literal, subject)
  }

  override Void walk(|Str key, Obj? val| f) { f("val", literal) }

  override Printer print(Printer out) { out.val(literal) }
}

**************************************************************************
** RangePattern
**************************************************************************

** Matches when subject is same type and within inclusive range: "400..499"
@NoDoc @Js
const class RangePattern : Pattern
{
  new make(FileLoc loc, Obj start, Obj end) : super(loc)
  {
    this.start = start
    this.end   = end
  }

  override ExprType type() { ExprType.rangePattern }

  const Obj start

  const Obj end

  override Bool match(AxonContext cx, Obj? subject)
  {
    subject?.typeof === start.typeof && start <= subject && subject <= end
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("start", start)
    f("end", end)
  }

  override Printer print(Printer out) { out.val(start).w("..").val(end) }
}

**************************************************************************
** SpecPattern
**************************************************************************

**
** Matches when subject is non-null and fits a spec: "Ahu", "ph::Site".
** For an enum spec a Str subject matches if it is a valid key.
**
@NoDoc @Js
const class SpecPattern : Pattern
{
  new make(TopName spec) : super(spec.loc) { this.spec = spec }

  override ExprType type() { ExprType.specPattern }

  const TopName spec

  override Bool match(AxonContext cx, Obj? subject)
  {
    if (subject == null) return false
    Spec s := spec.eval(cx)
    return cx.ns.fits(subject, s) || (s.isEnum && enumItem(s, subject) != null)
  }

  override Void walk(|Str key, Obj? val| f) { f("spec", spec) }

  override Printer print(Printer out) { out.expr(spec) }
}

**************************************************************************
** EnumPattern
**************************************************************************

**
** Matches enum item by its key: "CurStatus.ok".  The subject may be
** the Str key or a Fantom value bound to the enum spec.
**
@NoDoc @Js
const class EnumPattern : Pattern
{
  new make(TopName spec, Str item) : super(spec.loc)
  {
    this.spec = spec
    this.item = item
  }

  override ExprType type() { ExprType.enumPattern }

  const TopName spec

  const Str item

  override Bool match(AxonContext cx, Obj? subject)
  {
    Spec s := spec.eval(cx)
    if (!s.isEnum) throw EvalErr("Not enum spec: $s", cx, loc)
    itemSpec := s.slot(item, false) ?: throw EvalErr("Unknown enum item: ${s}.$item", cx, loc)
    return enumItem(s, subject) === itemSpec && (subject is Str || cx.ns.fits(subject, s))
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("spec", spec)
    f("item", item)
  }

  override Printer print(Printer out) { out.expr(spec).wc('.').w(item) }
}

**************************************************************************
** OrPattern
**************************************************************************

** Matches if any of the alternatives match: "200 or 204"
@NoDoc @Js
const class OrPattern : Pattern
{
  new make(Pattern[] alts) : super(alts.first.loc) { this.alts = alts }

  override ExprType type() { ExprType.orPattern }

  const Pattern[] alts

  override Bool match(AxonContext cx, Obj? subject)
  {
    for (i := 0; i<alts.size; ++i)
      if (alts[i].match(cx, subject)) return true
    return false
  }

  override Void walk(|Str key, Obj? val| f) { f("alts", alts) }

  override Printer print(Printer out)
  {
    alts.each |alt, i|
    {
      if (i > 0) out.w(" or ")
      alt.print(out)
    }
    return out
  }
}

