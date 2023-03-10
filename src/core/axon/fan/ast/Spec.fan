//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Mar 2023  Brian Frank  Creation
//

using concurrent
using data
using haystack

**
** Spec is the Axon AST for a DataSpec
**
@Js
internal const class Spec : Expr
{
  new make(Loc loc, Str? libName, Str name)
  {
    this.loc     = loc
    this.libName = libName
    this.name    = name
  }

  override ExprType type() { ExprType.spec }

  override const Loc loc

  const Str? libName

  const Str name

  override Obj? eval(AxonContext cx)
  {
    r := resolved.val
    if (r == null) resolved.val = r = cx.usings.resolve(name)
    return r
  }
  private const AtomicRef resolved := AtomicRef()

  override Printer print(Printer out)
  {
    out.w(nameToStr)
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("spec", nameToStr)
  }

  Str nameToStr()
  {
    if (libName != null)
      return libName + "::" + name
    else
      return name
  }

}

