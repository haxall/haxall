//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jul 2025  Brian Frank  Creation
//

using util
using xeto
using haystack
using haystack::Macro

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

    ns := XetoEnv.cur.createNamespaceFromNames(["axon", "hx"])

    return make {
      it.libPrefix       = props.get("libPrefix", "hx")
      it.templateHeader  = env.findFile(`etc/convert4/template-header.xeto`).readAllStr
      it.templateLibXeto = env.findFile(`etc/convert4/template-lib.xeto`).readAllStr
      it.dependVersions  = dependVersions
      it.ignore          = props.get("ignore", "").split(',').findAll { !it.isEmpty }
      it.funcMeta        = props.get("funcMeta", "").split(',')
      it.ns            = ns
    }
  }

  new make(|This| f) { f(this) }

  Str libPrefix := "hx"

  Str templateHeader

  Str templateLibXeto

  Str:Str dependVersions

  Str[] ignore

  Str[] funcMeta

  Namespace ns

  Str genHeader()
  {
    s := genMacro(templateHeader) |n| { null }
    return s.trim + "\n"
  }

  Str genMacro(Str template, |Str->Str?| resolve)
  {
    macro := Macro(template)
    vars := Str:Str[:]
    macro.vars.each |name|
    {
      vars[name] = resolve(name) ?: resolveVarBuiltin(name)
    }
    return macro.apply |var| { vars[var] }
  }

  Str resolveVarBuiltin(Str var)
  {
    switch (var)
    {
      case "date":    return Date.today.toLocale("D MMM YYYY")
      case "year":    return Date.today.toLocale("YYYY")
    }
    throw Err("Unknown template var: $var")
  }
}

