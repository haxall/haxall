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

**
** TypeRef is a spec type lookup either by qualified or unqualified name
**
@NoDoc @Js
const class TypeRef : Expr
{
  new make(Loc loc, Str? lib, Str name)
  {
    this.loc  = loc
    this.lib  = lib
    this.name = name
  }

  override ExprType type() { ExprType.typeRef }

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

