//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Oct 2026  Brian Frank  Creation
//

using util

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

** Matches when subject equals literal using Axon equality
@NoDoc @Js
const class LiteralPattern : Pattern
{
  new make(FileLoc loc, Obj? literal) : super(loc) { this.literal = literal }

  override ExprType type() { ExprType.literalPattern }

  const Obj? literal

  override Bool match(AxonContext cx, Obj? subject) { Eq.eqVals(literal, subject) }

  override Void walk(|Str key, Obj? val| f) { f("val", literal) }

  override Printer print(Printer out) { out.val(literal) }
}

