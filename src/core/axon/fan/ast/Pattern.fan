//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Oct 2026  Brian Frank  Creation
//

using util
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

