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
      binds := Str:Obj?[:]
      if (c.pattern.match(cx, s, binds)) return cx.callInNewFrame(c, Obj#.emptyList, c.loc, binds)
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
** SwitchCase is one "case" arm: a pattern and the body to evaluate when
** the pattern matches the switch subject.  The case is a function so its
** body is lexically scoped and called in a frame whose vars are the
** pattern bindings.
**
@NoDoc @Js
const class SwitchCase : Fn
{
  new make(FileLoc loc, Str name, Pattern pattern, Expr body)
    : super(loc, name, FnParam.none, body)
  {
    this.pattern = pattern
  }

  override ExprType type() { ExprType.switchCase }

  const Pattern pattern

  ** Evaluate body without evalAsFnBody so return exits enclosing function
  override Obj? doCall(AxonContext cx, Obj?[] args) { body.eval(cx) }

  ** Pattern bindings are bound within the body
  override Void doFreeVars(Str:Str acc)
  {
    inner := acc.dup
    pattern.eachBind |n| { bindVar(inner, n) }
    body.doFreeVars(inner)
    inner.each |v, n| { if (v == "free") acc[n] = v }
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("pattern", pattern)
    f("body", body)
  }

  override Printer print(Printer out)
  {
    out.w("case ").expr(pattern).w(" => ").expr(body)
  }
}
