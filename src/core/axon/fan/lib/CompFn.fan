//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Feb 2024  Brian Frank  Creation
//

using haystack
using concurrent
using xeto
using xeto::Comp
using xetom

**
** CompFn is an Axon function backed by a Xeto component blocks
**
@Js @NoDoc
const class CompFn : TopFn
{

  protected new make(Str name, Dict meta, CompParam[] params, Str xeto)
    : super(Loc(name), name, meta, params, Literal.nullVal)
  {
    this.xeto = xeto
  }

  const Str xeto

  override Bool isNative() { true }

  override Obj? callx(AxonContext cx, Obj?[] args, Loc callLoc)
  {
    // create component space from xeto
    ns := cx.ns
    cs := CompSpace(ns).load(xeto)

    // map input args to Var components
    root := cs.root
    params.each |CompParam p, i|
    {
      var := cs.readById(p.compId, false)
      if (var == null) return var
      var.set("val", args.getSafe(i))
    }

    // execute once
    cs.execute

    // get returns
    ret := cs.readById(Ref("returns"))
    return ret?.get("val")
  }

}

**************************************************************************
** CompParam
**************************************************************************

@Js @NoDoc
const class CompParam : FnParam
{
  new make(Spec spec) : super(spec.name)
  {
    compId = spec.meta["compId"] as Ref ?: Ref(spec.name)
  }

  const Ref compId
}

