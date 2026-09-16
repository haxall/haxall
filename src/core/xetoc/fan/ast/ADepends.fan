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

  ** Resolve the extended slot with the given name contributed by a
  ** depend lib mixin, walking the type inheritance graph including
  ** And compounds in priority order the same as Namespace.mixinsFor
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

  ** Libs this compile depends on.  Normally these are declared by the
  ** lib's pragma, but a compile with nothing declared to go on resolves
  ** against every lib in the namespace instead.  Computed on first read
  ** since it is not known until ParseLib has the pragma.
  once MLibDepend[] list()
  {
    compiler.useNsDepends ? nsToDepends : compiler.lib.pragma.depends
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

