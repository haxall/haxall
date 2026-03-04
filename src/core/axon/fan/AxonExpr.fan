//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Mar 2026  Brian Frank  Creation
//

using xeto
using haystack
using concurrent

**
** AxonExpr wraps an expression string
**
@Js @NoDoc
const class AxonExpr
{
  ** Wrap string - the string is *not* parsed for syntax correctness
  static new fromStr(Str expr, Bool checked := true) { make(expr) }

  ** Constructor
  private new make(Str expr) { this.expr = expr}

  ** Expression string
  const Str expr

  ** Return expression string
  override Str toStr() { expr }
}

