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
  }

//////////////////////////////////////////////////////////////////////////
// ProjLibs
//////////////////////////////////////////////////////////////////////////

  const FileBase fb

  const Str[] bootLibNames

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
  internal const AtomicRef mapRef := AtomicRef() // updated by MNamespace.load

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

  Str[] readProjLibNames()
  {
    // proj libs are defined in "libs.txt"
    return fb.read("libs.txt").readAllLines.findAll |line|
    {
      line = line.trim
      return !line.isEmpty && !line.startsWith("//")
    }
  }
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

