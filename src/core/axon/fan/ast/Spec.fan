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
** Spec is an expression that evaluates to a DataSpec
**
@Js
internal abstract const class Spec : Expr
{
  abstract override DataSpec? eval(AxonContext cx)
}

**************************************************************************
** SpecRef
**************************************************************************

**
** SpecRef a DataSpec lookup by name from either using lib or a local definition.
**
@Js
internal const class SpecRef : Spec
{
  new make(Loc loc, Str? lib, Str name)
  {
    this.loc  = loc
    this.lib  = lib
    this.name = name
  }

  override ExprType type() { ExprType.specRef }

  override const Loc loc

  const Str? lib

  const Str name

  override DataSpec? eval(AxonContext cx)
  {
    // qualified type
    if (lib != null) return cx.usings.data.lib(lib).slotOwn(name)

    // try local varaible definition
    local := cx.getVar(name) as DataSpec
    if (local != null) return local

    // resolve from usings
    return cx.usings.resolve(name)
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

**************************************************************************
** SpecDerive
**************************************************************************

**
** SpecDerive derives a new DataSpec with meta/slots
**
@Js
internal const class SpecDerive : Spec
{
  new make(Loc loc, Str name, Spec base, Dict meta, [Str:Spec]? slots)
  {
    this.loc   = loc
    this.name  = name
    this.base  = base
    this.meta  = meta
    this.slots = slots
  }

  override ExprType type() { ExprType.specDerive }

  override const Loc loc

  const Str name

  const Spec base

  const Dict meta

  const [Str:Spec]? slots

  override DataSpec? eval(AxonContext cx)
  {
    base := base.eval(cx)

    [Str:DataSpec]? slots := null
    if (this.slots != null)
      slots = this.slots.map |Spec ast->DataSpec| { ast.eval(cx) }

    return cx.usings.data.derive(name, base, meta, slots)
  }

  override Printer print(Printer out)
  {
    // TODO
    out.w(base.toStr)
  }

  override Void walk(|Str key, Obj? val| f)
  {
    // TODO
    f("spec", base.toStr)
  }

}

