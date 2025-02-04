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
** FuncSpec models a 'sys::Func' spec that models a function signature
**
@Js
const mixin FuncSpec : Spec
{
  ** Number of parameters
  abstract Int arity()

  ** Parameter types in positional order
  abstract Spec[] params()

  ** Return type
  abstract Spec returns()
}

