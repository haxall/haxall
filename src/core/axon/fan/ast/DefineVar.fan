//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   04 Sep 2009  Brian Frank  Creation
//

**
** DefineVar is used to bind a new variable name to a value.
**
@Js
internal const class DefineVar : Expr
{
  new make(Loc loc, Str name, Expr val)
  {
    this.loc  = loc
    this.name = name
    this.val  = val
  }

  override ExprType type() { ExprType.def }

  const override Loc loc

  const Str name

  const Expr val

  override Obj? eval(AxonContext cx)
  {
    cx.def(name, val.eval(cx), loc)
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("name", name)
    f("val", val)
  }

  override Printer print(Printer out)
  {
    out.w(name).w(": ").expr(val)
  }

}