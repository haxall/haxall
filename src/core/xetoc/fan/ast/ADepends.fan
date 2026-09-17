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

  ** Iterate every lib in the dependency scope include transients and my own
  Void eachLibInScope(|Lib| f)
  {
    libs.each(f)
    f(compiler.lib)
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

  ** Walk the dependency chain to build the list of mixins for given type
  Spec[] mixinsFor(Spec type)
  {
    x := mixinsForCache[type.qname]
    if (x == null) mixinsForCache[type.qname] = x = resolveMixinsFor(type)
    return x
  }

  private Spec[] resolveMixinsFor(Spec type)
  {
    acc := Str:Spec[:]

    // add mixins registered on base using cache
    XetoUtil.eachBase(type) |base|
    {
      mixinsFor(base).each |x| { acc[x.qname] = x }
    }

    // find my own mixins
    eachLibInScope |lib|
    {
      x := lib.mixinFor(type, false)
      if (x != null) acc[x.qname] = x
    }

    return acc.isEmpty ? Spec#.emptyList : acc.vals
  }

  ** TODO - to be removed
  Spec? slotx(Spec? type, Str name)
  {
    while (type != null && type.isAst) type = type.base
    if (libs == null || type == null) return null
    Spec? match := null
    XetoUtil.eachInherited(type) |t|
    {
      if (match != null || !t.isType) return
      match = libs.eachWhile |lib| { lib.mixinFor(t, false)?.slotsOwn?.get(name, false) }
    }
    return match
  }

  private Str:Spec[] mixinsForCache := [:]
}

