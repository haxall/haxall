//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Oct 2026  Brian Frank  Creation
//

using util

**
** Switch expression with pattern matching cases
**
@NoDoc @Js
const class SwitchExpr : Expr
{
  new make(FileLoc loc, Expr subject, SwitchCase[] cases, Expr? defExpr)
  {
    this.loc     = loc
    this.subject = subject
    this.cases   = cases
    this.defExpr = defExpr
  }

  override ExprType type() { ExprType.switchExpr }

  override const FileLoc loc

  const Expr subject

  const SwitchCase[] cases

  const Expr? defExpr

  override Obj? eval(AxonContext cx)
  {
    s := subject.eval(cx)
    for (i := 0; i<cases.size; ++i)
    {
      c := cases[i]
      scope := c.matchScope(cx, cx.curScope, s)
      if (scope != null) return cx.run(EvalFrame(scope, c.body))
    }
    return defExpr?.eval(cx)
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("subject", subject)
    f("cases", cases)
    f("default", defExpr)
  }

  override Printer print(Printer out)
  {
    out.atomicStart.w("switch (").expr(subject).w(")").nl
    out.indent
    cases.each |c| { c.print(out).nl }
    if (defExpr != null) out.w("default => ").expr(defExpr).nl
    out.unindent
    return out.w("end").atomicEnd
  }
}

**************************************************************************
** SwitchCase
**************************************************************************

**
** SwitchCase is one "case" arm: a pattern, optional guard, and the body
** to evaluate when both match the switch subject.
**
@NoDoc @Js
const class SwitchCase : Expr
{
  new make(FileLoc loc, Pattern pattern, Expr? guard, Expr body)
  {
    this.loc     = loc
    this.pattern = pattern
    this.guard   = guard
    this.body    = body
  }

  override ExprType type() { ExprType.switchCase }

  override const FileLoc loc

  const Pattern pattern

  ** Condition evaluated with the pattern's bindings: "if (x > 0)"
  const Expr? guard

  const Expr body

  **
  ** Match subject against the pattern and guard.  Return the scope nested
  ** in parent with the pattern's bindings which the guard was evaluated
  ** in and the body should be, or null if the pattern or guard fails.
  **
  AxonScope? matchScope(AxonContext cx, AxonScope parent, Obj? subject)
  {
    binds := Str:Obj?[:]
    if (!pattern.match(cx, subject, binds)) return null
    scope := AxonScope.makeNested(parent)
    binds.each |v, n| { scope.set(n, v) }
    if (guard != null && !(Bool)cx.run(EvalFrame(scope, guard))) return null
    return scope
  }

  override Obj? eval(AxonContext cx) { throw UnsupportedErr("SwitchCase cannot be evaluated") }

  override Void walk(|Str key, Obj? val| f)
  {
    f("pattern", pattern)
    f("guard", guard)
    f("body", body)
  }

  override Printer print(Printer out)
  {
    out.w("case ").expr(pattern)
    if (guard != null) out.w(" if (").expr(guard).w(")")
    return out.w(" => ").expr(body)
  }
}

