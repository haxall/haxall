//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Mar 2023  Brian Frank  Creation
//   24 Jul 2025  Brian Frank  Garden City (redesign from TypeRef)
//

using concurrent
using xeto
using haystack

**
** TopName either an unqualified or qualified top-level name for type or func
**
@NoDoc @Js
const class TopName : Expr
{
  new make(Loc loc, Str? lib, Str name)
  {
    this.loc  = loc
    this.lib  = lib
    this.name = name
  }

  override ExprType type() { ExprType.topName }

  override const Loc loc

  const Str? lib

  const Str name

  override Bool isTopNameType() { name[0].isUpper }

  override Obj? eval(AxonContext cx)
  {
if (isTopNameType)
{
    // qualified type
    if (lib != null) return cx.ns.lib(lib).type(name)

    // resolve from usings
    return cx.ns.unqualifiedType(name)
}
else
{
  return cx.findTop(nameToStr)
}
  }

  override Printer print(Printer out)
  {
    out.w(nameToStr)
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("topName", nameToStr)
  }

  Str nameToStr()
  {
    if (lib != null)
      return lib + "::" + name
    else
      return name
  }
}

