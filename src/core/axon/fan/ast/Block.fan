//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   04 Sep 2009  Brian Frank  Creation
//

using concurrent

**
** Block is a sequence of expressions.  The entire block
** evaluates to the last expression unless there is a return.
**
@Js
internal const class Block : Expr
{
  new make(Expr[] exprs)
  {
    if (exprs.isEmpty) throw ArgErr("exprs cannot be empty")
    this.exprs = exprs
  }

  override ExprType type() { ExprType.block }

  override Loc loc() { exprs.first.loc }

  const Expr[] exprs

  override Obj? eval(AxonContext cx)
  {
    Obj? result := null
    exprs.each |expr| { result = expr.eval(cx) }
    return result
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("exprs", exprs)
  }

  override Printer print(Printer out)
  {
    out.w("do").nl
    out.indent
    exprs.each |expr| { expr.print(out).eos.nl }
    out.unindent
    out.w("end").nl
    return out
  }
}