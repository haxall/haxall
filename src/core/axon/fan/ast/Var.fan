//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   04 Sep 2009  Brian Frank  Creation
//

using util

**
** Variable attempts to lookup to a variable name within its scope.
**
@Js
internal const class Var : Expr
{
  new make(FileLoc loc, Str name) { this.loc = loc; this.name = name }

  override ExprType type() { ExprType.var }

  override const FileLoc loc

  const Str name

  override Obj? eval(AxonContext cx) { cx.resolve(name, loc) }

  override Str toStr() { name }

  override Void walk(|Str key, Obj? val| f) { f("name", name) }

  override Printer print(Printer out) { out.w(name) }

}

