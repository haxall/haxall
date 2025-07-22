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

**
** FileRepo is a file system based repo that uses the the Fantom path to
** find zip versions in "lib/xeto/" and sourceversion in "src/xeto/".
**
const class FileRepo : LibRepo
{
  new make(XetoEnv env)
  {
    this.env = env
    rescan
  }

  const Log log := Log.get("xeto")

  const XetoEnv env

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
    scan.list
  }

  override LibVersion[]? versions(Str name, Bool checked := true)
  {
    versions := scan.map.get(name)
    if (versions != null) return versions
    if (checked) throw UnknownLibErr(name)
    return null
  }

  override LibVersion? latest(Str name, Bool checked := true)
  {
    versions := versions(name, checked)
    if (versions != null) return versions.last
    if (checked) throw UnknownLibErr(name)
    return null
  }

  override LibVersion? latestMatch(LibDepend d, Bool checked := true)
  {
    versions := versions(d.name, checked)
    if (versions != null)
    {
      match := versions.eachrWhile |x| { d.versions.contains(x.version) ? x : null }
      if (match != null) return match
    }
    if (checked) throw UnknownLibErr(d.toStr)
    return null
  }

  override LibVersion? version(Str name, Version version, Bool checked := true)
  {
    versions := versions(name, checked)
    if (versions != null)
    {
      index := versions.binaryFind |x| { version <=> x.version }
      if (index >= 0) return versions[index]
    }
    if (checked) throw UnknownLibErr("$name-$version")
    return null
  }

  override LibVersion[] solveDepends(LibDepend[] libs)
  {
    DependSolver(this, libs).solve
  }

  LibNamespace createNamespace(LibVersion[] libs)
  {
    makeNamespace(libs, null)
  }

  LibNamespace createFromNames(Str[] names)
  {
    depends := names.map |n->LibDepend| { LibDepend(n) }
    vers    := solveDepends(depends)
    return createNamespace(vers)
  }

  LibNamespace createFromData(Dict[] recs)
  {
    libNames := XetoUtil.dataToLibs(recs)
    vers := libNames.map |libName->LibVersion| { latest(libName) }
    return createNamespace(vers)
  }

  private LibNamespace makeNamespace(LibVersion[] versions, [Str:File]? build)
  {
    init := LocalNamespaceInit(env, this, versions, build)
    return LocalNamespace(init)
  }

}

