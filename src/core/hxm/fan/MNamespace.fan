//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Jul 2025  Brian Frank  Creation
//

using xeto
using haystack
using folio
using hx
using hx4
using xetoc

**
** HxNamespace implementation
**
const class MNamespace : LocalNamespace, Namespace
{
  static MNamespace load(FileRepo repo, Str[] required)
  {
    // we only use latest version for required
    requiredDepends := required.map |n->LibDepend|
    {
      latest := repo.latest(n, false) ?: throw Err("Missing required boot lib: $n")
      return LibDepend(latest)
    }

    // solve depends
    versions := repo.solveDepends(requiredDepends)

    return make(LocalNamespaceInit(repo, versions, null, repo.names))
  }

  new make(LocalNamespaceInit init) : super(init) {}

  override once NamespaceExts exts()
  {
    ext := spec("hx::Ext")
    acc := Str:ExtDef[:]
    libs.each |lib|
    {
      lib.specs.each |spec|
      {
        if (spec.isa(ext) && spec.meta.missing("abstract"))
          acc[spec.qname] = MExtDef(spec)
      }
    }
    return MExtDefs(acc)
  }
}

