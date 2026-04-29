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

  override LibVersion[] libs() { scan.list }

  override LibVersion? lib(Str name, Bool checked := true)
  {
    lib := scan.map[name]
    if (lib != null) return lib
    if (checked) throw UnknownLibErr(name)
    return null
  }

  override LibVersion[] resolveDepends(LibDepend[] libs)
  {
    DependSolver(this, libs).solve
  }

  Namespace createNamespace(LibVersion[] libs)
  {
    makeNamespace(libs)
  }

  Namespace resolveNamespace(Str[] names)
  {
    if (names.isEmpty) names = ["sys"]
    depends := names.map |n->LibDepend| { LibDepend(n) }
    vers    := resolveDepends(depends)
    return createNamespace(vers)
  }

  Namespace deriveNamespace(Dict[] recs)
  {
    libNames := XetoUtil.dataToLibs(recs)
    return resolveNamespace(libNames)
  }

  private Namespace makeNamespace(LibVersion[] versions)
  {
    MNamespace(env, versions)
  }

}

