//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   03 Mar 2025  Matthew Giannini  Creation
//

using concurrent
using util
using haystack
using hx
using xeto
using axon
using xeto::Comp

**
** Component that evaluates an Axon expression
**
@Gen
class AxonComp : HxComp
{
  @Gen virtual Str axon { get {get("axon")} set {set("axon", it)} }

  override Void onExecute()
  {
    cx := AxonContext.curAxon
// echo("=== onExecute")
// echo(axon)
// dump
    varSpec := cx.ns.spec("sys.comp::Var")
    scope := AxonScope()
    this.each |v, name|
    {
      if (v isnot Comp) return
      comp := v as Comp
      if (!comp.spec.isa(varSpec)) return
      scope.set(name, comp.get("val"))
    }
    ret := cx.evalExpr(cx.parse(axon), scope)
    (get("returns") as Comp)?.set("val", ret)
  }
}

