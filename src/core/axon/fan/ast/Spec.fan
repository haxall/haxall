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
  new make(Loc loc, Str name, Spec base, SpecMetaTag[]? meta, [Str:Spec]? slots)
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

  const SpecMetaTag[]? meta

  const [Str:Spec]? slots

  override DataSpec? eval(AxonContext cx)
  {
    base  := base.eval(cx)
    meta  := evalMeta(cx)
    slots := evalSlots(cx)
    return cx.usings.data.derive(name, base, meta, slots)
  }

  private Dict evalMeta(AxonContext cx)
  {
    m := meta
    if (m == null || m.isEmpty) return Etc.dict0
    switch (m.size)
    {
      case 1: return Etc.dict1(m[0].name, m[0].eval(cx))
      case 2: return Etc.dict2(m[0].name, m[0].eval(cx), m[1].name, m[1].eval(cx))
      case 3: return Etc.dict3(m[0].name, m[0].eval(cx), m[1].name, m[1].eval(cx), m[2].name, m[2].eval(cx))
      case 4: return Etc.dict4(m[0].name, m[0].eval(cx), m[1].name, m[1].eval(cx), m[2].name, m[2].eval(cx), m[3].name, m[3].eval(cx))
    }

    acc := Str:Obj[:]
    m.each |x| { acc[x.name] = x.eval(cx) }
    return Etc.dictFromMap(acc)
  }

  private [Str:DataSpec]? evalSlots(AxonContext cx)
  {
    if (slots == null) return null
    return slots.map |Spec ast->DataSpec| { ast.eval(cx) }
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

**************************************************************************
** SpecMetaTag
**************************************************************************

**
** SpecMetaTag models one name/value pair for spec meta.  Each
** value must be a const literal or a SpecRef to evaluate at runtime
**
@Js
internal const class SpecMetaTag
{
  new make(Str name, Expr val)
  {
    this.name = name
    this.val  = val
  }

  Obj eval(AxonContext cx)
  {
    if (val.type === ExprType.list && name == "ofs")
      return ((ListExpr)val).vals.map |x->DataSpec| { x.eval(cx) }
    else
      return val.eval(cx)
  }

  const Str name
  const Expr val
}


