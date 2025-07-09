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
// Init
//////////////////////////////////////////////////////////////////////////

  static MProjLibs init(ProjBoot boot)
  {
    log := boot.log
    repo := boot.xetoEnv.repo

    // boot libs are defined by boot loader
    bootLibs := initLibs(repo, log, ProjLibState.boot, boot.bootLibs)

    // proj libs are defined in "libs.txt"
    fb := boot.nsfb
    projLibNames := fb.read("libs.txt").readAllLines.findAll |line|
    {
      line = line.trim
      return !line.isEmpty && !line.startsWith("//")
    }

    // resolve the project lib names
    projLibs := initLibs(repo, log, ProjLibState.enabled, projLibNames)

    // build map
    acc := Str:MProjLib[:]
    projLibs.each |x| { acc[x.name] = x }
    bootLibs.each |x| { acc[x.name] = x } // trumps proj libs

    // create instance
    return make(fb, acc)
  }

  private static MProjLib[] initLibs(LibRepo repo, Log log, ProjLibState state, Str[] names)
  {
    acc := MProjLib[,]
    names.each |n|
    {
      x := repo.latest(n, false)
      if (x == null)
      {
        if (state.isBoot)
          log.err("Boot lib not found: $n")
        else
          log.err("Proj lib not found: $n")
        acc.add(MProjLib(n, null, "", ProjLibState.notFound))
      }
      else
      {
        acc.add(MProjLib(n, x.version, x.doc, state))
      }
    }
    return acc
  }

  private new make(FileBase fb, Str:MProjLib map)
  {
    this.fb = fb
    this.mapRef.val = map.toImmutable
  }

//////////////////////////////////////////////////////////////////////////
// ProjLibs
//////////////////////////////////////////////////////////////////////////

  const FileBase fb

  override ProjLib[] list() { map.vals.sort }

  override Bool has(Str name) { map.containsKey(name) }

  override ProjLib? get(Str name, Bool checked := true)
  {
    lib := map[name]
    if (lib != null) return lib
    if (checked) throw UnknownExtErr(name)
    return null
  }
  internal Str:ProjLib map() { mapRef.val }
  private const AtomicRef mapRef := AtomicRef()

  override ProjLib[] installed()
  {
    return ProjLib[,]
  }

  override Grid status(Bool installed := false)
  {
    gb := GridBuilder()
    gb.addCol("name").addCol("state").addCol("version").addCol("doc")
    list.each |x|
    {
      gb.addRow([x.name, x.state.name, x.version.toStr, x.doc])
    }
    return gb.toGrid
  }

}

**************************************************************************
** MProjLib
**************************************************************************

const class MProjLib : ProjLib
{
  new make(Str name, Version? version, Str doc, ProjLibState state)
  {
    this.name    = name
    this.version = version
    this.doc     = doc
    this.state   = state
  }

  override const Str name
  override const Version? version
  override const Str doc
  override const ProjLibState state
  override Int compare(Obj that)
  {
    a := this
    b := (ProjLib)that
    if (a.state == b.state) return a.name <=> b.name
    return a.state <=> b.state
  }
  override Str toStr() { "$name [$state]" }

}

