//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    9 Mar 2026  Brian Frank  Creation
//

using xeto
using xetom
using haystack

**
**
** Instance comp func backed by instance dict
**
@Js
internal const class AxonCompFunc : MCompFunc
{
  new make(Comp self, Str name, Dict val) : super(name)
  {
    this.name   = name
    this.meta    = val
    this.argName = funcType(self).func.params[0].name
  }

  const Dict meta

  const Str argName

  override Spec funcType(Comp self)
  {
    ns := self.spi.ns
    ref := meta["funcType"] as Ref
    if (ref == null) return ns.lib("sys.comp").spec("CompFuncDefaultType")
    return ns.spec(ref.id)
  }

  override Obj? doCall(Comp self, Obj? arg)
  {
    AxonContext.curAxon.evalInNewFrame(expr, ["this":self, argName:arg])
  }

  once Expr expr()
  {
    axon := meta["axon"] as Str ?: throw Err("No axon for CompFunc")
    return Parser(Loc.eval, axon.in).expr
  }
}

