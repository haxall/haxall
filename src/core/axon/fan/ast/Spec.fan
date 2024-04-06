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
    if (lib != null) return cx.usings.env.lib(lib).type(name)

    // try local varaible definition
    local := cx.getVar(name) as Spec
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
** SpecSlotRef
**************************************************************************

**
** SpecSlotRef a slot path within SpecTypeRef
**
@Js
internal const class SpecSlotRef : SpecExpr
{
  new make(SpecTypeRef typeRef, Str[] slots)
  {
    this.typeRef = typeRef
    this.slots = slots
  }

  override ExprType type() { ExprType.specSlotRef }

  override Loc loc() { typeRef.loc }

  const SpecTypeRef typeRef

  const Str[] slots

  override Spec? eval(AxonContext cx)
  {
    spec := typeRef.eval(cx)
    for (i := 0; i<slots.size; ++i)
    {
      name := slots[i]
      x := spec.slot(name, false)
      if (x == null) throw UnknownSpecErr("${spec.qname}.${name}")
      spec = x
    }
    return spec
  }

  override Printer print(Printer out)
  {
    typeRef.print(out)
    slots.each |slot| { out.w(".").w(slot) }
    return out
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("slots", slots)
  }

}

**************************************************************************
** SpecDerive
**************************************************************************

**
** SpecDerive derives a new Spec with meta/slots
**
@Js
internal const class SpecDerive : SpecExpr
{
  new make(Loc loc, Str name, SpecExpr base, SpecMetaTag[]? meta, [Str:SpecExpr]? slots)
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

  const SpecExpr base

  const SpecMetaTag[]? meta

  const [Str:SpecExpr]? slots

  override Spec? eval(AxonContext cx)
  {
    base  := base.eval(cx)
    meta  := evalMeta(cx)
    slots := evalSlots(cx)
    return cx.usings.ns.derive(name, base, meta, slots)
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

  private [Str:Spec]? evalSlots(AxonContext cx)
  {
    if (slots == null) return null
    return slots.map |SpecExpr ast->Spec| { ast.eval(cx) }
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
      return ((ListExpr)val).vals.map |x->Spec| { x.eval(cx) }
    else
      return val.eval(cx)
  }

  const Str name
  const Expr val
}

