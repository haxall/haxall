//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Nov 2024  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

**
** AST namesapce
**
internal class ANamespace : CNamespace
{
  new make(Init step)
  {
    this.compiler = step.compiler
    this.ns = step.ns
  }

  CSpec? global(Str name)
  {
    g := globals[name]
    if (g != null) return g as CSpec
    g = doGlobal(name)
    globals[name] = g ?: "not-found"
    return g as CSpec
  }

  private CSpec? doGlobal(Str name)
  {
    if (ns != null)
    {
      global := ns.global(name, false)
      if (global != null) return (CSpec)global
    }

    return compiler.lib?.top(name)
  }

  override Void eachSubtype(CSpec type, |CSpec| f)
  {
    // iterate types from imported namespace only
    // if base type is not in the AST being compiled
    if (ns != null && type is XetoSpec) ns.eachSubtype(type, f)

    // iterate my own types
    if (compiler.lib != null)
    {
      compiler.lib.tops.each |x|
      {
        if (x.isType && x.cisa(type)) f(x)
      }
    }
  }

  const MNamespace? ns
  XetoCompiler compiler
  Str:Obj globals := [:]
}

