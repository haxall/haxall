//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//    9 Jul 2025  Brian Frank  Redesign from HxdRuntimeLibs
//

using concurrent
using xeto
using haystack
using xetoc
using hx
using hx4

** Temp shim
const class ShimNamespaceMgr : MProjLibs, ShimLibs
{
  static ShimNamespaceMgr init(File topDir)
  {
    dir := topDir + `ns/`
    libsTxt := dir + `libs.txt`
    if (!libsTxt.exists) libsTxt.out.printLine("// Stub $DateTime.now").close
    mgr := make(dir)
    // echo(">>> load shim"); mgr.ns.dump
    return mgr
  }

  private new make(File dir) : super.makeShim(dir, shimBootLibNames)
  {
  }

  static once Str[] shimBootLibNames()
  {
    repo := XetoEnv.cur.repo
    names := LibNamespace.defaultSystemLibNames
    return names.findAll |n|
    {
      repo.latest(n, false) != null
    }
  }

  const override MProjSpecs specs := MProjSpecs(this)
}


**
** ProjLibs implementation
**
const class MProjLibs : ProjLibs
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(ProjBoot boot)
  {
    this.fb = boot.nsfb
    this.bootLibNames = boot.bootLibs
    this.repo = boot.repo
    this.log = boot.log
    this.version = boot.version
    doReload(readProjLibNames)
  }

  new makeShim(File dir, Str[] bootLibNames)
  {
    this.fb = DiskFileBase(dir)
    this.repo = XetoEnv.cur.repo
    this.log = Log.get("xeto")
    this.bootLibNames = bootLibNames
    this.version = typeof.pod.version
    doReload(readProjLibNames)
  }

//////////////////////////////////////////////////////////////////////////
// Lookup
//////////////////////////////////////////////////////////////////////////

  const DiskFileBase fb

  const Log log

  const FileRepo repo

  const Version version

  const Str[] bootLibNames

  ProjNamespace ns() { nsRef.val }

  override ProjLib[] list() { map.vals }

  override Bool has(Str name) { map.containsKey(name) }

  override ProjLib? get(Str name, Bool checked := true)
  {
    lib := map[name]
    if (lib != null) return lib
    if (checked) throw UnknownExtErr(name)
    return null
  }
  internal Str:MProjLib map() { mapRef.val }

  override ProjLib[] installed()
  {
    acc := this.map.dup
    repo.libs.each |n|
    {
      if (acc[n] != null) return
      v := repo.latest(n)
      acc[n] = MProjLib.makeDisabled(v)
    }
    return acc.vals
  }

  override Grid status(Dict? opts := null)
  {
    // use list or installed base on opts
    if (opts == null) opts = Etc.dict0
    libs := opts.has("installed") ? installed : list

    // sort based on status, then name
    libs.sort |a, b|
    {
      cmp := a.status <=> b.status
      if (cmp != 0) return cmp
      return a.name <=> b.name
    }

    // build grid
    gb := GridBuilder()
    gb.addCol("name").addCol("libStatus").addCol("boot").addCol("version").addCol("doc").addCol("err")
    libs.each |x|
    {
      gb.addRow([
        x.name,
        x.status.name,
        Marker.fromBool(x.isBoot),
        x.version?.toStr,
        x.doc,
        x.err?.toStr,
      ])
    }
    return gb.toGrid
  }

//////////////////////////////////////////////////////////////////////////
// Modification
//////////////////////////////////////////////////////////////////////////

  override Void add(Str name) { addAll([name]) }

  override Void addAll(Str[] names)
  {
    if (names.isEmpty) return
    lock.lock
    try
      doAdd(names)
    finally
      lock.unlock
  }

  override Void remove(Str name) { removeAll([name]) }

  override Void removeAll(Str[] names)
  {
    if (names.isEmpty) return
    lock.lock
    try
      doRemove(names)
    finally
      lock.unlock
  }

  override Void clear()
  {
    echo("TODO MProjLib.clear")
  }

  override Void reload()
  {
    echo("TODO MProjLib.reload")
  }

  private const Lock lock := Lock.makeReentrant

  private Void doAdd(Str[] names)
  {
    // check dup names were not passed in to keep things clean
    checkDupNames(names)

    // remove names already installed or check they exists
    map := this.map
    toAddVers := Str:LibVersion[:]
    repo := XetoEnv.cur.repo
    names.each |n|
    {
      cur := map[n]
      if (cur != null) return
      ver := repo.latest(n)
      toAddVers.add(n, ver)
    }
    if (toAddVers.isEmpty) return

    // build list of all current plus to-add
    newProjLibs := Str:Str[:]
    allVers := Str:LibVersion[:]
    map.each |x|
    {
      n := x.name
      if (!x.isBoot) newProjLibs[n] = n
      if (x.status.isOk) allVers[n] = repo.version(n, x.version)
    }
    toAddVers.each |x|
    {
      n := x.name
      newProjLibs[n] = n
      allVers.add(n, x)
    }

    // check depends, reload ns, save libs.txt
    reloadNewProjLibs(allVers, newProjLibs)
  }

  private Void doRemove(Str[] names)
  {
    // check dup names were not passed in to keep things clean
    nameMap := checkDupNames(names)

    // build list of all current minus to-remove
    newProjLibs := Str:Str[:]
    allVers := Str:LibVersion[:]
    map.each |x|
    {
      n := x.name

      // check if a lib to remove
      isRemove := nameMap.containsKey(n)
      if (isRemove)
      {
        if (x.isBoot) throw CannotRemoveBootLibErr(n)
        return
      }

      // update our lists
      if (!x.isBoot) newProjLibs[n] = n
      if (x.status.isOk) allVers[n] = repo.version(n, x.version)
    }

    // check depends, reload ns, save libs.txt
    reloadNewProjLibs(allVers, newProjLibs)
  }

  private Void reloadNewProjLibs(Str:LibVersion allVers, Str:Str newProjLibNameMap)
  {
    // verify that the new all LibVersions have met depends
    vers := allVers.vals
    LibVersion.orderByDepends(vers)

    // now we are ready, rebuild our projLibNames list
    newProjLibNames := newProjLibNameMap.vals.sort
    doReload(newProjLibNames)

    // update our libs.txt file
    writeProjLibNames(newProjLibNames)
  }

  private Str:Str checkDupNames(Str[] names)
  {
    map := Str:Str[:]
    names.each |n|
    {
      if (map[n] != null) throw DuplicateNameErr(n)
      else map[n] = n
    }
    return map
  }

//////////////////////////////////////////////////////////////////////////
// File I/O
//////////////////////////////////////////////////////////////////////////

  Str[] readProjLibNames()
  {
    // proj libs are defined in "libs.txt"
    return fb.read("libs.txt").readAllLines.findAll |line|
    {
      line = line.trim
      return !line.isEmpty && !line.startsWith("//")
    }
  }

  Void writeProjLibNames(Str[] names)
  {
    buf := Buf()
    buf.capacity = names.size * 16
    buf.printLine("// " + DateTime.now.toLocale)
    names.each |n| { buf.printLine(n) }

    // proj libs are defined in "libs.txt"
    fb.write("libs.txt", buf)
  }

  Void writePragma(LibVersion[] vers)
  {
    // TODO: temp shim
    buf := Buf()
    buf.printLine("// Project library")
    buf.printLine("pragma: Lib <")
    buf.printLine("  version: $version.toStr.toCode")
    buf.printLine("  depends: {")
    vers.each |ver| { buf.printLine("    {lib:$ver.name.toCode}") }
    buf.printLine("  }")
    buf.printLine(">")
    fb.write("lib.xeto", buf)
    // echo(fb.read("lib.xeto").readAllStr)
  }

//////////////////////////////////////////////////////////////////////////
// Reload
//////////////////////////////////////////////////////////////////////////

  private Void doReload(Str[] projLibNames)
  {
    // first find an installed LibVersion for each lib
    vers := Str:LibVersion[:]
    nameToIsBoot := Str:Bool[:]
    projLibNames.each |n | { vers.setNotNull(n, repo.latest(n, false)); nameToIsBoot[n] = false }
    bootLibNames.each |n | { vers.setNotNull(n, repo.latest(n, false)); nameToIsBoot[n] = true }

    // check depends and remove libs with a dependency error
    versToUse := vers.dup
    dependErrs := Str:Err[:]
    LibVersion.checkDepends(vers.vals).each |err|
    {
      n := err.name
      dependErrs[n] = err
      versToUse.remove(n)
    }

    // at this point should we should have a safe versions list to create namespace
    nsVers := versToUse.vals
    writePragma(nsVers)
    nsVers.add(FileLibVersion.makeProj(fb.dir, version))
    ns := ProjNamespace(LocalNamespaceInit(repo, nsVers, null, repo.names), log)
    ns.libs // force sync load

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

    // update my libs and ns
    this.nsRef.val = ns
    this.mapRef.val = acc.toImmutable
  }

  // updated by reload
  private const AtomicRef nsRef := AtomicRef()
  private const AtomicRef mapRef := AtomicRef()

}

**************************************************************************
** MProjLib
**************************************************************************

const class MProjLib : ProjLib
{
  internal new makeOk(Str name, Bool isBoot, LibVersion v)
  {
    this.name    = name
    this.isBoot  = isBoot
    this.status  = ProjLibStatus.ok
    this.version = v.version
    this.doc     = v.doc
  }

  internal new makeDisabled(LibVersion v)
  {
    this.name    = v.name
    this.isBoot  = false
    this.status  = ProjLibStatus.disabled
    this.version = v.version
    this.doc     = v.doc
  }

  internal new makeErr(Str name, Bool isBoot, ProjLibStatus status, Err err)
  {
    this.name   = name
    this.isBoot = isBoot
    this.status = status
    this.err    = err
  }

  override const Str name
  override const Bool isBoot
  override const ProjLibStatus status
  override const Version? version
  override const Str? doc
  override const Err? err

  override Str toStr() { "$name [$status]" }

  override Int compare(Obj that)
  {
    a := this
    b := (ProjLib)that
    cmp := a.status <=> b.status
    if (cmp != 0) return cmp
    return a.name <=> b.name
  }

}

