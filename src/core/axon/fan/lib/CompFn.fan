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
using xetoEnv

**
** CompFn is an Axon function backed by a Xeto component blocks
**
@Js @NoDoc
const class CompFn : TopFn
{

  protected new make(Str name, Dict meta, FnParam[] params, Str xeto)
    : super(Loc(name), name, meta, params, Literal.nullVal)
  {
    this.xeto = xeto
  }

  const Str xeto

  override Bool isNative() { true }

  override Obj? callx(AxonContext cx, Obj?[] args, Loc callLoc)
  {
    // create component space from xeto
    ns := cx.xeto
    cs := CompSpace(ns).load(xeto)

    // map input args to Var components by parameter name
    root := cs.root
    params.each |p, i|
    {
      var := root.get(p.name) as Comp
      if (var == null) return var
      var.set("val", args.getSafe(i))
    }

    // execute once
    cs.execute

    // get returns
    ret := root.get("returns") as Comp
    return ret?.get("val")
  }

}

