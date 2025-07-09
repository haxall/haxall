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
** Namespace implementation
**
const class ProjNamespace : LocalNamespace, Namespace
{
  static ProjNamespace load(FileRepo repo, Log log, MProjLibs libs)
  {
    // get boot/proj lib names
    boot := libs.bootLibNames
    proj := libs.readProjLibNames

    // first find a lib version for each lib
    vers := Str:LibVersion[:]
    nameToIsBoot := Str:Bool[:]
    proj.each |n | { vers.setNotNull(n, repo.latest(n, false)); nameToIsBoot[n] = false }
    boot.each |n | { vers.setNotNull(n, repo.latest(n, false)); nameToIsBoot[n] = true }

    // check depends and remove libs with a dependency error
    versToUse := vers.dup
    dependErrs := Str:Err[:]
    LibVersion.checkDepends(vers.vals).each |err|
    {
      n := err.name
      dependErrs[n] = err
      versToUse.remove(n)
    }

    // at this point should we should have a safe versions list
    ns := make(LocalNamespaceInit(repo, versToUse.vals, null, repo.names), log)
    ns.libs // force load

    // now update MProjLibs map of MProjLib
    acc := Str:MProjLib[:]
    nameToIsBoot.each |isBoot, n|
    {
      // check if we have lib installed
      ver := vers[n]
      if (ver == null)
      {
        acc[n] = MProjLib.makeErr(n, isBoot, ProjLibStatus.notFound, UnknownLibErr("Lib is not installed"))
        return
      }

      // check if we had dependency error
      dependErr := dependErrs[n]
      if (dependErr != null)
      {
        acc[n] = MProjLib.makeErr(n, isBoot, ProjLibStatus.err, dependErr)
        return
      }

      // check status of lib in namespace itself
      libStatus := ns.libStatus(n)
      if (!libStatus.isOk)
      {
        acc[n] = MProjLib.makeErr(n, isBoot, ProjLibStatus.err, ns.libErr(n) ?: Err("Lib status not ok: $libStatus"))
        return
      }

      // this lib is ok and loaded
      acc[n] = MProjLib.makeOk(n, isBoot, ver)
    }
    libs.mapRef.val = acc.toImmutable

    // return the namespace
    return ns
  }

  private new make(LocalNamespaceInit init, Log log) : super(init)
  {
    this.log = log
  }

  const Log log

  override once NamespaceExts exts()
  {
    ext := spec("hx::Ext")
    acc := Str:ExtDef[:]
    libs.each |lib|
    {
      lib.specs.each |spec|
      {
        if (spec.isa(ext) && spec.meta.missing("abstract"))
        {
          if (!spec.name.endsWith("Ext"))
            return log.err("Ext name must end with Ext: $spec")
          else
            acc[spec.qname] = MExtDef(spec)
        }
      }
    }
    return MExtDefs(acc)
  }
}

