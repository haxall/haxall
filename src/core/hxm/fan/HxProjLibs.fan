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
using xetom
using xetoc
using hx

**
** ProjLibs implementation
**
const class HxProjLibs : ProjLibs
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(HxProj proj, HxBoot boot)
  {
    this.proj = proj
    this.isSys = proj.isSys
    this.fb = boot.nsfb
    this.bootLibNames = boot.bootLibs
    this.repo = boot.repo
    this.log = boot.log
    this.specsRef = HxProjSpecs(this)
  }

  internal HxNamespace init()
  {
    return doReload(readProjLibNames)
  }

//////////////////////////////////////////////////////////////////////////
// Lookup
//////////////////////////////////////////////////////////////////////////

  const HxProj proj

  const Bool isSys

  const DiskFileBase fb

  const Log log

  const FileRepo repo

  const Str[] bootLibNames

  const HxProjSpecs specsRef

  virtual ProjSpecs specs() { specsRef }

  HxNamespace ns() { nsRef.val }

  Str[] projLibNames() { projLibNamesRef.val }

  override ProjLib[] list() { map.vals }

  override Bool has(Str name) { map.containsKey(name) }

  override ProjLib? get(Str name, Bool checked := true)
  {
    lib := map[name]
    if (lib != null) return lib
    if (checked) throw UnknownLibErr(name)
    return null
  }
  internal Str:HxProjLib map() { mapRef.val }

  override ProjLib[] installed()
  {
    acc := this.map.dup
    repo.libs.each |n|
    {
      if (acc[n] != null) return
      v := repo.latest(n)
      acc[n] = HxProjLib.makeDisabled(v)
    }
    return acc.vals
  }

  override Grid status(Dict? opts := null)
  {
    // use list or installed base on opts
    if (opts == null) opts = Etc.dict0
    libs := opts.has("installed") ? installed : list

    // sort based basis, then status, then name
    libs.sort |a, b|
    {
      if (a.basis != b.basis) return a.basis <=> b.basis
      cmp := a.status <=> b.status
      if (cmp != 0) return cmp
      return a.name <=> b.name
    }

    // build grid
    gb := GridBuilder()
    gb.setMeta(Etc.dict1("projName", proj.name))
    gb.addCol("name").addCol("libBasis").addCol("libStatus").addCol("version").addCol("doc").addCol("err")

    // add row for proj lib
    pxName := XetoUtil.projLibName
    pxVer:= ns.version(pxName, false)
    if (pxVer != null) gb.addRow([
      pxName,
      ProjLibBasis.projBoot.name,
      ns.libStatus(pxName)?.toStr ?: "err",
      pxVer?.version?.toStr,
      pxVer?.doc,
      specs.libErrMsg,
    ])

    // add rest of the rows
    libs.each |x|
    {
      gb.addRow([
        x.name,
        x.basis.name,
        x.status.name,
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
    doReload(Str[,])
  }

  override Void reload()
  {
    doReload(readProjLibNames)
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
      if (!x.basis.isBoot) newProjLibs[n] = n
      if (x.status.isOk) allVers[n] = repo.version(n, x.version)
    }
    toAddVers.each |x|
    {
      n := x.name
      newProjLibs[n] = n
      allVers.add(n, x)
    }

    // check depends, reload ns, save libs.txt
    updateProjLibs(allVers, newProjLibs)
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
        if (x.basis.isBoot) throw CannotRemoveBootLibErr(n)
        return
      }

      // update our lists
      if (!x.basis.isBoot) newProjLibs[n] = n
      if (x.status.isOk) allVers[n] = repo.version(n, x.version)
    }

    // check depends, reload ns, save libs.txt
    updateProjLibs(allVers, newProjLibs)
  }

  private Void updateProjLibs(Str:LibVersion allVers, Str:Str newProjLibNameMap)
  {
    // verify that the new all LibVersions have met depends
    vers := allVers.vals
    LibVersion.orderByDepends(vers)

    // now we are ready, rebuild our projLibNames list
    newProjLibNames := newProjLibNameMap.vals.sort
    ns := doReload(newProjLibNames)

    // update our libs.txt file
    writeProjLibNames(newProjLibNames)

    // notify project
    this.proj.onLibsModified(ns)
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

//////////////////////////////////////////////////////////////////////////
// Reload
//////////////////////////////////////////////////////////////////////////

  private HxNamespace doReload(Str[] projLibNames)
  {
    // first find an installed LibVersion for each lib
    vers := Str:LibVersion[:]
    basisBoot    := isSys ? ProjLibBasis.sysBoot : ProjLibBasis.projBoot
    basisNonBoot := isSys ? ProjLibBasis.sys : ProjLibBasis.proj
    nameToBasis := Str:ProjLibBasis[:]
    projLibNames.each |n | { vers.setNotNull(n, repo.latest(n, false)); nameToBasis[n] = basisNonBoot }
    bootLibNames.each |n | { vers.setNotNull(n, repo.latest(n, false)); nameToBasis[n] = basisBoot }

    // check depends and remove libs with a dependency error
    versToUse := vers.dup
    dependErrs := Str:Err[:]
    while (true)
    {
      errs := LibVersion.checkDepends(versToUse.vals)
      if (errs.isEmpty) break
      errs.each |err|
      {
        n := err.name
        dependErrs[n] = err
        versToUse.remove(n)
        log.warn("Cannot load: $n.toCode: $err")
      }
    }

    // at this point should we should have a safe versions list to create namespace
    nsVers := versToUse.vals
    if (proj.sys.info.rt.isHxd)
      nsVers.add(FileLibVersion.makeProj(fb.dir, proj.sys.info.version))
    ns := HxNamespace(LocalNamespaceInit(repo, nsVers, null))
    ns.libs // force sync load

    // now update HxProjLibs map of HxProjLib
    acc := Str:HxProjLib[:]
    nameToBasis.each |basis, n|
    {
      // check if we have lib installed
      ver := vers[n]
      if (ver == null)
      {
        acc[n] = HxProjLib.makeErr(n, basis, ProjLibStatus.notFound, UnknownLibErr("Lib is not installed"))
        return
      }

      // check if we had dependency error
      dependErr := dependErrs[n]
      if (dependErr != null)
      {
        acc[n] = HxProjLib.makeErr(n, basis, ProjLibStatus.err, dependErr)
        return
      }

      // check status of lib in namespace itself
      libStatus := ns.libStatus(n)
      if (!libStatus.isOk)
      {
        acc[n] = HxProjLib.makeErr(n, basis, ProjLibStatus.err, ns.libErr(n) ?: Err("Lib status not ok: $libStatus"))
        return
      }

      // this lib is ok and loaded
      acc[n] = HxProjLib.makeOk(n, basis, ver)
    }

    // update my libs and ns
    this.nsRef.val = ns
    this.mapRef.val = acc.toImmutable
    this.projLibNamesRef.val = projLibNames.toImmutable
    return ns
  }

  // updated by reload
  private const AtomicRef nsRef := AtomicRef()
  private const AtomicRef mapRef := AtomicRef()
  private const AtomicRef projLibNamesRef := AtomicRef()

}

**************************************************************************
** HxProjLib
**************************************************************************

const class HxProjLib : ProjLib
{
  internal new makeOk(Str name, ProjLibBasis basis, LibVersion v)
  {
    this.name    = name
    this.basis   = basis
    this.status  = ProjLibStatus.ok
    this.version = v.version
    this.doc     = v.doc
  }

  internal new makeDisabled(LibVersion v)
  {
    this.name    = v.name
    this.basis   = ProjLibBasis.disabledProj
    this.status  = ProjLibStatus.disabled
    this.version = v.version
    this.doc     = v.doc
  }

  internal new makeErr(Str name, ProjLibBasis basis, ProjLibStatus status, Err err)
  {
    this.name   = name
    this.basis  = basis
    this.status = status
    this.err    = err
  }

  override const Str name
  override const ProjLibBasis basis
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

