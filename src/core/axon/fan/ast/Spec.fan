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
  new make(Loc loc, Str? libName, Str name, Dict meta, [Str:Spec]? slots)
  {
    this.loc     = loc
    this.libName = libName
    this.name    = name
    this.meta    = meta
    this.slots   = slots
  }

  override ExprType type() { ExprType.spec }

  override const Loc loc

  const Str? libName

  const Str name

  const Dict meta

  const [Str:Spec]? slots

  override Obj? eval(AxonContext cx)
  {
    r := resolved.val
    if (r == null) resolved.val = r = resolve(cx)
    return r
  }
  private const AtomicRef resolved := AtomicRef()

  Bool isTypeOnly()
  {
    meta.isEmpty && (slots == null || slots.isEmpty)
  }

  private DataSpec resolve(AxonContext cx)
  {
    type := cx.usings.resolve(name)
    if (isTypeOnly) return type
    return cx.usings.data.derive(name, type, meta)
  }

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

