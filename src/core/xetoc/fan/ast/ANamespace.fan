//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Nov 2024  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** AST namespace: the compile-time CNamespace scoped to the depends
** closure overlaid with the lib under compile
**
@Js
internal class ANamespace : CNamespace
{
  new make(MXetoCompiler compiler)
  {
    this.compiler = compiler
  }

  ** Iterate types in scope: depends closure plus the lib under
  ** compile.  Only valid once Assemble completes: the lib under
  ** compile yields its assembled specs so isa identity matches
  ** specs resolved thru the assembled lib.
  override Void eachTypeThatIs(Spec type, |Spec| f)
  {
    compiler.depends.all.each |lib|
    {
      lib.types.each |x| { if (x.isa(type)) f(x) }
    }
    compiler.lib?.asm?.types?.each |x| { if (x.isa(type)) f(x) }
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

    // my own mixins from depends closure and the lib under compile
    compiler.depends.all.each |lib| { addMixinFor(acc, lib, type) }
    if (compiler.lib != null) addMixinFor(acc, compiler.lib, type)

    return acc.isEmpty ? Spec#.emptyList : acc
  }

  private static Void addMixinFor(Spec[] acc, Lib lib, Spec type)
  {
    x := lib.mixinFor(type, false)
    if (x != null && !acc.containsSame(x)) acc.add(x)
  }

  MXetoCompiler compiler
  private Str:Spec[] mixinsForCache := [:]
}
