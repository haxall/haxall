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
using xetoEnv
using haystack::UnknownLibErr

**
** FileRepo is a file system based repo that uses the the Fantom path to
** find zip versions in "lib/xeto/" and sourceversion in "src/xeto/".
**
const class FileRepo : LibRepo
{
  new make(File[] path := Env.cur.path)
  {
    this.path = path
    rescan
  }

  const NameTable names := NameTable()

  const Log log := Log.get("xeto")

  const File[] path

  internal FileRepoScan scan() { scanRef.val }
  private const AtomicRef scanRef := AtomicRef()

  override Str toStr() { "$typeof.qname ($scan.ts.toLocale)" }

  override This rescan()
  {
    scanRef.val = FileRepoScanner(log, names, path).scan
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

  override LibNamespace createNamespace(LibVersion[] libs)
  {
    LocalNamespace(null, names, libs, this, null)
  }

  override LibNamespace createOverlayNamespace(LibNamespace base, LibVersion[] libs)
  {
    LocalNamespace(base, names, libs, this, null)
  }

  override LibNamespace build(LibVersion[] build)
  {
    // turn verions to lib depends
    buildAsDepends := build.map |v->LibDepend|
    {
      if (!v.isSrc) throw ArgErr("Not source lib: $v")
      return LibDepend(v.name, LibDependVersions(v.version))
    }

    // solve dependency graph for full list of libs
    libs := solveDepends(buildAsDepends)

    // build map of lib name to
    buildFiles := Str:File[:]
    build.each |v| { buildFiles[v.name] = XetoUtil.srcToLibZip(v) }

    // create namespace and force all libs to be compiled
    ns := LocalNamespace(null, names, libs, this, buildFiles)
    ns.libs

    // report which libs could not be compiled
    ns.versions.each |v|
    {
      if (ns.libStatus(v.name).isErr) echo("ERROR: could not compile $v.name.toCode")
    }

    return ns
  }

  override LibNamespace systemNamespace()
  {
    ns := systemNamespaceRef.val
    if (ns == null) installSystemNamespace(ns = createDefaultSystemNamespace)
    return ns
  }

  private const AtomicRef systemNamespaceRef := AtomicRef()

  override Void installSystemNamespace(LibNamespace ns)
  {
    systemNamespaceRef.val = ns
  }

  private LibNamespace createDefaultSystemNamespace()
  {
    libs := ["sys"]
    vers := LibVersion[,]
    libs.each |libName|
    {
      vers.addNotNull(latest(libName, false))
    }
    return createNamespace(vers)
  }

}

