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

  ** Get this spec as a method annotated with '@HxApi' facet
  ** that takes an 'hx::HxApiReq' parameter.
  @NoDoc abstract Obj? api(Bool checked := true)

  ** Get this spec as an 'axon::Fn' instance
  @NoDoc abstract Obj? axon(Bool checked := true)
}

**************************************************************************
** XetoAxonPlugin
**************************************************************************

**
** Plugin for axon function support
**
@NoDoc @Js
const abstract class XetoAxonPlugin
{
  ** Parse or reflect spec to an 'axon::Fn'
  abstract Obj? parse(Spec s)
}

