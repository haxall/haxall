//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Feb 2025  Brian Frank  Creation
//

using concurrent
using util

**
** Function specific APIS for 'sys::Func' specs
**
@Js
const mixin SpecFunc
{
  ** Number of parameters
  abstract Int arity()

  ** Parameter types in positional order
  abstract Spec[] params()

  ** Return type
  abstract Spec returns()

  ** Get the thunk used to call this function
  abstract Thunk thunk()
}

**************************************************************************
** Api
**************************************************************************

** Api facet is applied to Fantom methods to expose them as xeto funcs
@Js facet class Api {}

**************************************************************************
** Thunk
**************************************************************************

**
** Thunk wraps a function implementation
**
@Js
const mixin Thunk
{
  ** Call the function with given args
  abstract Obj? callList(Obj?[]? args := null)

  ** Call function with up to 8 params
  abstract Obj? call(Obj? a := null, Obj? b := null, Obj? c := null, Obj? d := null,
                     Obj? e := null, Obj? f := null, Obj? g := null, Obj? h := null)

  ** Empty arg list
  @NoDoc static const Obj?[] noArgs := Obj?[,]
}

**************************************************************************
** StaticMethodThunk
**************************************************************************

**
** StaticMethodThunk
**
@NoDoc @Js
const class StaticMethodThunk : Thunk
{
  new make(Method m)
  {
    if (!m.isStatic) throw ArgErr()
    this.method = m
  }

  const Method method

  override Obj? callList(Obj?[]? args := null)
  {
    method.callList(args ?: noArgs)
  }

  override Obj? call(Obj? a := null, Obj? b := null, Obj? c := null, Obj? d := null,
                     Obj? e := null, Obj? f := null, Obj? g := null, Obj? h := null)
  {
    method.call(a, b, c, d, e, f, g, h)
  }
}

**************************************************************************
** AxonThunkParser
**************************************************************************

**
** StaticMethodThunk
**
@NoDoc @Js
abstract const class AxonThunkParser
{
  static once AxonThunkParser cur() { Type.find("axon::ThunkParser").make }

  abstract Thunk parse(Str src)
}

