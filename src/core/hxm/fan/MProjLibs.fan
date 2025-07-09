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
    reload(readProjLibNames)
  }

//////////////////////////////////////////////////////////////////////////
// Lookup
//////////////////////////////////////////////////////////////////////////

  const FileBase fb

  const Log log

  const FileRepo repo

  const Str[] bootLibNames

  ProjNamespace ns() { nsRef.val }

  override ProjLib[] list() { map.vals.sort }

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
    return ProjLib[,]
  }

  override Grid status(Bool installed := false)
  {
    gb := GridBuilder()
    gb.addCol("name").addCol("status").addCol("version").addCol("more")
    list.each |x|
    {
      gb.addRow([x.name, x.status.name, x.version?.toStr, x.doc ?: x.err?.toStr])
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

  private const Lock lock := Lock.makeReentrant

  private Void doAdd(Str[] names)
  {
    // verify no dup names
    dupNames := Str:Str[:]
    names.each |n|
    {
      if (dupNames[n] != null) throw DuplicateNameErr(n)
      dupNames[n] = n
    }

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

    // build list of all current and to add
    newProjLibNameMap := Str:Str[:]
    allVers := Str:LibVersion[:]
    map.each |x|
    {
      n := x.name
      if (!x.isBoot) newProjLibNameMap[n] = n
      if (x.status.isOk) allVers[n] = repo.version(n, x.version)
    }
    toAddVers.each |x|
    {
      n := x.name
      newProjLibNameMap[n] = n
      allVers.add(n, x)
    }

    // verify that the new all LibVersions have met depends
    LibVersion.orderByDepends(allVers.vals)

    // now we are ready, rebuild our projLibNames list
    newProjLibNames := newProjLibNameMap.vals.sort
    reload(newProjLibNames)

    // update our libs.txt file
    writeProjLibNames(newProjLibNames)
  }

  private Void doRemove(Str[] names)
  {
    throw Err("TODO")
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

//////////////////////////////////////////////////////////////////////////
// Reload
//////////////////////////////////////////////////////////////////////////

  private Void reload(Str[] projLibNames)
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
    ns := ProjNamespace(LocalNamespaceInit(repo, versToUse.vals, null, repo.names), log)
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

