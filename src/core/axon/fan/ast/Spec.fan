//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Mar 2023  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using haystack::Dict

**
** SpecExpr is an expression that evaluates to a `xeto::Spec`
**
@Js
internal abstract const class SpecExpr : Expr
{
  abstract override Spec? eval(AxonContext cx)
}

**************************************************************************
** SpecTypeRef
**************************************************************************

**
** SpecTypeRef is a DataType lookup by name from either using lib or a local definition.
**
@Js
internal const class SpecTypeRef : SpecExpr
{
  new make(Loc loc, Str? lib, Str name)
  {
    this.loc  = loc
    this.lib  = lib
    this.name = name
  }

  override ExprType type() { ExprType.specTypeRef }

  override const Loc loc

  const Str? lib

  const Str name

  override Spec? eval(AxonContext cx)
  {
    // qualified type
    if (lib != null) return cx.xeto.lib(lib).type(name)

    // try local varaible definition
    local := cx.getVar(name) as Spec
    if (local != null) return local

    // resolve from usings
    return cx.xeto.unqualifiedType(name)
  }

  override Printer print(Printer out)
  {
    out.w(nameToStr)
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("specRef", nameToStr)
  }

  Str nameToStr()
  {
    if (lib != null)
      return lib + "::" + name
    else
      return name
  }
}

