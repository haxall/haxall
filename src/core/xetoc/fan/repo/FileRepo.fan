//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//  4 Apr 2024   Brian Frank  Creation
//

using concurrent
using util
using xeto
using xetom
using haystack

**
** FileRepo is a file system based repo that uses the the Fantom path to
** find zip versions in "lib/xeto/" and sourceversion in "src/xeto/".
**
const class FileRepo : MLocalRepo
{
  new make(MEnv env) : super(env)
  {
    rescan
  }

  const Log log := Log.get("xeto")

  internal FileRepoScan scan() { scanRef.val }
  private const AtomicRef scanRef := AtomicRef()

  override Str toStr() { "$typeof.qname ($scan.ts.toLocale)" }

  override This rescan()
  {
    scanRef.val = FileRepoScanner(log, env.path).scan
    return this
  }

  override Str[] libs()
  {
    scan.libNames
  }

  override LibVersion[] versions(Str name, Dict? opts := null)
  {
    list := scan.map.get(name)
    if (list == null) return LibVersion#.emptyList

    // contrainsts
    versions := XetoUtil.optVersionConstraints(opts)
    if (versions != null) list = list.findAll { versions.contains(it.version) }

    // limit
    limit := XetoUtil.optInt(opts, "limit", Int.maxVal)
    if (list.size > limit) list = list[0..<limit]
    return list
  }

  override LibVersion[] solveDepends(LibDepend[] libs)
  {
    DependSolver(this, libs).solve
  }

  Namespace createNamespace(LibVersion[] libs)
  {
    makeNamespace(libs)
  }

  Namespace createFromNames(Str[] names)
  {
    if (names.isEmpty) names = ["sys"]
    depends := names.map |n->LibDepend| { LibDepend(n) }
    vers    := solveDepends(depends)
    return createNamespace(vers)
  }

  Namespace createFromData(Dict[] recs)
  {
    libNames := XetoUtil.dataToLibs(recs)
    return createFromNames(libNames)
  }

  private Namespace makeNamespace(LibVersion[] versions)
  {
    MNamespace(env, versions)
  }

}

