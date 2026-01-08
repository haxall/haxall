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
** Function specific APIS for 'sys::Func' specs via `Spec.func`.
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

  ** Has a thunk been initialized for this function
  @NoDoc abstract Bool hasThunk()

  ** Is this a template function
  @NoDoc abstract Bool isTemplate()
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
  ** Call the function with given args. Must be called within context
  abstract Obj? callList(Obj?[]? args := null)
}

**************************************************************************
** ThunkFactory
**************************************************************************

**
** ThunkFactory
**
@NoDoc @Js
const abstract class ThunkFactory
{
  ** Factory for the VM - implementation lives in Axon
  static once ThunkFactory cur() { Type.find("axon::AxonThunkFactory").make }

  ** Factory hook
  abstract Thunk create(Spec spec, Pod? pod)

  ** Hook for XetoIO.readAxon
  abstract Dict readAxon(Namespace ns, Str src, Dict opts)
}

