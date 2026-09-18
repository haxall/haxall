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
** AST dependencies and imported namespace handling
**
@Js
internal class ADepends
{
  new make(MXetoCompiler compiler)
  {
    this.compiler = compiler
  }

  MXetoCompiler compiler                // make
  [Str:XetoLib]? libs                   // Resolve

  ** Libs this compile depends on.  Normally these are declared by the
  ** lib's pragma, but a compile with nothing declared to go on resolves
  ** against every lib in the namespace instead.  Computed on first read
  ** since it is not known until ParseLib has the pragma.
  once MLibDepend[] list()
  {
    compiler.useNsDepends ? nsToDepends : compiler.lib.pragma.depends
  }

  ** Resolved dependency scope libs; only valid once Resolve completes
  once Lib[] libsInScope()
  {
    if (libs == null) throw Err("Not Resolved")
    acc := Lib[,]
    list.each |d| { acc.addNotNull(libs[d.name]) }
    acc.addNotNull(compiler.lib)
    return acc
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

  ** Walk the dependency chain to build the list of mixins for the given
  ** spec.  Slots resolve thru their owning type so results are cached
  ** once per type and layered thru the base chain.  Only valid once
  ** InheritBase completes: mixinFor matches by base identity, which
  ** requires every top's base to be resolved.
  Spec[] mixinsFor(Spec spec)
  {
    spec = spec.type
    x := mixinsForCache[spec.qname]
    if (x == null) mixinsForCache[spec.qname] = x = resolveMixinsFor(spec)
    return x
  }

  private Spec[] resolveMixinsFor(Spec type)
  {
    acc := Spec[,]

    // add mixins registered on base using cache
    XetoUtil.eachBase(type) |base|
    {
      mixinsFor(base).each |x| { if (!acc.containsSame(x)) acc.add(x) }
    }

    // find my own mixins
    libsInScope.each |lib|
    {
      x := lib.mixinFor(type, false)
      if (x != null && !acc.containsSame(x)) acc.add(x)
    }

    return acc.isEmpty ? Spec#.emptyList : acc
  }

  private Str:Spec[] mixinsForCache := [:]
}

