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
    props := pod.props(`config.props`, 0ms)

    dependVersions := Str:Str[:]
    props.each |v, n|
    {
      if (n.startsWith("depend.")) dependVersions.set(n[7..-1], v)
    }

    return make {
      it.libPrefix       = pod.config("libPrefix", "hx")
      it.templateLibXeto = env.findFile(`etc/convert4/template-lib.xeto`).readAllStr
      it.dependVersions  = dependVersions
    }
  }

  new make(|This| f) { f(this) }

  Str libPrefix := "hx"

  Str templateLibXeto

  Str:Str dependVersions
}

