//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jul 2025  Brian Frank  Creation
//

using concurrent
using xeto

**
** XetoFn is an Axon function backed by a xeto function thunk
**
const class XetoFn : TopFn
{

** TODO: don't want to create over and over
  new make(Spec x)
    : super(Loc(x.name), x.name, x.meta, FnParam[,], Literal.nullVal)
  {
    this.xeto = x
  }

  const Spec xeto

  override Bool isNative() { true }

  override Obj? callLazy(AxonContext cx, Expr[] args, Loc loc)
  {
// TODO: total hack to get over lazy args
    thunk := xeto.func.thunk
    if (thunk is StaticMethodThunk)
    {
      fn := FantomFn.reflectMethod(((StaticMethodThunk)thunk).method, xeto.name, xeto.meta, null)
      return fn.callLazy(cx, args, loc)
    }
    else
    {
      throw Err("TODO")
    }
  }

}

