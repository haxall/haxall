//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jul 2025  Brian Frank  Creation
//

using util
using haystack

**
** AST configuration
**
class AConfig
{
  static AConfig load()
  {
    env := Env.cur
    pod := AConfig#.pod
    return make {
      libPrefix       = pod.config("libPrefix", "hx")
      templateLibXeto = env.findFile(`etc/convert4/template-lib.xeto`).readAllStr
    }
  }

  new make(|This| f) { f(this) }

  Str libPrefix := "hx"

  Str templateLibXeto
}

