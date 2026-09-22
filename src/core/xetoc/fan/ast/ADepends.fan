//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Dec 2023  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** AST dependency bookkeeping for the compile.  Every method here
** excludes the lib under compile itself; ANamespace layers the
** compile's own lib over this scope.
**
@Js
internal class ADepends
{
  new make(MXetoCompiler compiler)
  {
    this.compiler = compiler
  }

  MXetoCompiler compiler                // make
  [Str:XetoLib]? direct                 // Resolve; direct depends by name

  ** Declared depends of this compile.  Normally these are declared by
  ** the lib's pragma, but a compile with nothing declared to go on
  ** resolves against every lib in the namespace instead.  Computed on
  ** first read since it is not known until ParseLib has the pragma.
  once MLibDepend[] declared()
  {
    compiler.useNsDepends ? nsToDepends : compiler.lib.pragma.depends
  }

  ** Transitive closure of the direct depends; only valid once
  ** Resolve completes
  once XetoLib[] all()
  {
    if (direct == null) throw Err("Not Resolved")
    acc := Str:XetoLib[:]
    acc.ordered = true
    direct.each |lib| { doAll(acc, lib) }
    return acc.vals
  }

  private Void doAll(Str:XetoLib acc, XetoLib lib)
  {
    if (acc[lib.name] != null) return
    acc[lib.name] = lib
    lib.depends.each |d|
    {
      x := compiler.ns.lib(d.name, false)
      if (x != null) doAll(acc, x)
    }
  }

  ** Every lib in the namespace, excluding ourself and any lib in error
  private MLibDepend[] nsToDepends()
  {
    compiler.ns.versions.mapNotNull |ver->MLibDepend?|
    {
      name := ver.name
      if (compiler.libName == name) return null
      if (compiler.ns.lib(name, false) == null) return null
      return MLibDepend(name, LibDependVersions.wildcard, FileLoc.synthetic)
    }
  }
}
