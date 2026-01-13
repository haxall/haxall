//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   03 Mar 2025  Matthew Giannini  Creation
//

using concurrent
using haystack
using hx
using xeto
using axon
using xeto::Comp

**
** A component that evaluates an Axon expression
**
class AxonComp : HxComp
{
  /* ionc-start */

  virtual Str axon { get {get("axon")} set {set("axon", it)} }

  /* ionc-end */

  private static const Loc loc := Loc.make("AxonComp", 0)

  override Void onExecute()
  {
    cx := AxonContext.curAxon
// echo("=== onExecute")
// echo(axon)
// dump
    varSpec := cx.ns.spec("sys.comp::Var")
    this.each |v, name|
    {
      if (v isnot Comp) return
      comp := v as Comp
      if (!comp.spec.isa(varSpec)) return
      val := comp.get("val")
// echo("defOrAssign: ${name} = ${val}")
      cx.defOrAssign(name, val, loc)
    }
    ret := cx.eval(axon)
    (get("returns") as Comp)?.set("val", ret)
  }
}

