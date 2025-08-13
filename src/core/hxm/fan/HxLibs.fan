//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//    9 Jul 2025  Brian Frank  Redesign from HxdRuntimeLibs
//

using concurrent
using crypto
using xeto
using haystack
using xetom
using xetoc
using hx
using hxUtil

**
** RuntimeLibs implementation
**
const class HxLibs : RuntimeLibs
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(HxRuntime rt, HxBoot boot)
  {
    if (!rt.isSys && !boot.bootLibs.isEmpty)
      throw Err("Proj boot cannot specify boot libs")

    this.rt           = rt
    this.isSys        = rt.isSys
    this.myBasis      = isSys ? RuntimeLibBasis.sys : RuntimeLibBasis.proj
    this.env          = boot.xetoEnv
    this.log          = boot.log
    this.bootLibNames = boot.bootLibs
  }

  internal HxNamespace init()
  {
    doUpdate(null, null, true)
  }

//////////////////////////////////////////////////////////////////////////
// Lookup
//////////////////////////////////////////////////////////////////////////

  const HxRuntime rt

  const Bool isSys

  const RuntimeLibBasis myBasis

  const Str[] bootLibNames  // always empty for proj

  const Log log

  const override XetoEnv env

  LibRepo repo() { env.repo }

  TextBase tb() { rt.tb }

  HxNamespace ns() { nsRef.val }

  override RuntimeLib[] list() { map.vals }

  override Bool has(Str name) { map.containsKey(name) }

  override RuntimeLib? get(Str name, Bool checked := true)
  {
    lib := map[name]
    if (lib != null) return lib
    if (checked) throw UnknownLibErr(name)
    return null
  }
  private Str:HxLib map() { mapRef.val }


  override RuntimeLibPack pack() { packRef.val }
  private const AtomicRef packRef := AtomicRef()

  override RuntimeLib[] installed()
  {
    acc := this.map.dup
    env.repo.libs.each |n|
    {
      if (acc[n] != null) return
      if (n.startsWith("hx.hxd.")) return
      v := repo.latest(n)
      acc[n] = HxLib(v, RuntimeLibBasis.disabled)
    }
    return acc.vals
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  override Grid status(Dict? opts := null)
  {
    if (opts == null) opts = Etc.dict0

    // use list or installed based on opts
    ns := this.ns
    libs := opts.has("installed") ? installed : this.list.dup

    // check sysOnly/projOnly
    show := (opts["show"] as Str)?.lower ?: ""
    if (opts.has("sysOnly") || show.contains("sys"))
    {
      libs = libs.findAll |x|
      {
        if (x.basis.isDisabled) return x.isSysOnly
        return !x.basis.isProj
      }
    }
    else if (opts.has("projOnly") || show.contains("proj"))
    {
      libs = libs.findAll |x|
      {
        if (x.basis.isDisabled) return !x.isSysOnly
        return x.basis.isProj
      }
    }

    // sort based basis, then name (but move proj to top)
    libs.sort |a, b|
    {
      if (a.basis != b.basis) return a.basis <=> b.basis
      return a.name <=> b.name
    }
    libs.moveTo(libs.find { it.name == "proj" }, 0)

    // build grid
    gb := GridBuilder()
    gb.setMeta(Etc.dict1("projName", rt.name))
    gb.addCol("name").addCol("libBasis").addCol("libStatus").addCol("sysOnly")
      .addCol("version").addCol("doc").addCol("err")

    // add rest of the rows
    libs.each |HxLib x|
    {
      n := x.name
      gb.addRow([
        n,
        x.basis.name,
        ns.libStatus(n, false)?.name ?: "disabled",
        Marker.fromBool(x.isSysOnly),
        x.ver.isNotFound ? null : x.ver.version.toStr,
        x.ver.doc,
        ns.libErr(n, false)?.toStr
      ])
    }
    grid := gb.toGrid

    search := opts["search"] as Str
    if (search != null) grid = grid.filter(Filter.search(search))

    return grid
  }

//////////////////////////////////////////////////////////////////////////
// Public Modification APIs
//////////////////////////////////////////////////////////////////////////

  override Void add(Str name)
  {
    update([name], null)
  }

  override Void addAll(Str[] names)
  {
    update(checkDupNames(names), null)
  }

  override Void remove(Str name)
  {
    update(null, [name])
  }

  override Void removeAll(Str[] names)
  {
    update(null, checkDupNames(names))
  }

  override Void clear()
  {
    writeLibNames(Str[,])
    reload
  }

  override Void reload()
  {
    update(null, null)
  }

  private Str[] checkDupNames(Str[] names)
  {
    map := Str:Str[:]
    names.each |n|
    {
      if (map[n] != null) throw DuplicateNameErr(n)
      else map[n] = n
    }
    return names
  }

  override Void addDepends(Str name, Bool self)
  {
    // solve depends we need to enable too
    depends := repo.solveDepends([LibDepend(name)])
    names := depends.map |d->Str| { d.name }
    names = names.findAll |n| { !has(n) }
    if (!self) names.remove(name)
    addAll(names)
  }

//////////////////////////////////////////////////////////////////////////
// File I/O
//////////////////////////////////////////////////////////////////////////

  Str[] readLibNames()
  {
    // proj libs are defined in "libs.txt"
    buf :=  tb.read("libs.txt", false)
    if (buf == null) return Str#.emptyList
    return buf.splitLines.findAll |line|
    {
      line = line.trim
      return !line.isEmpty && !line.startsWith("//")
    }
  }

  Void writeLibNames(Str[] names)
  {
    buf := StrBuf()
    buf.capacity = names.size * 16
    buf.add("// ").add(DateTime.now.toLocale).addChar('\n')
    names.each |n| { buf.add(n).addChar('\n') }

    // proj libs are defined in "libs.txt"
    tb.write("libs.txt", buf.toStr)
  }

//////////////////////////////////////////////////////////////////////////
// Update
//////////////////////////////////////////////////////////////////////////

  private HxNamespace update(Str[]? add, Str[]? remove)
  {
    lock.lock
    try
      return doUpdate(add, remove, false)
    finally
      lock.unlock
  }

  private HxNamespace doUpdate(Str[]? adds, Str[]? removes, Bool init)
  {
    // build list of all the libs that should be in my namespace
    acc := Str:HxLib[:]
    updateBootLibs(acc)
    updateSysLibs(acc)
    updateConfiguredLibs(acc)
    updateProjLib(acc)
    updateAdds(acc, adds)
    updateRemoves(acc, removes)

    // create namespace
    nsVers := acc.vals.map |x->LibVersion| { x.ver }
    nsOpts := Etc.dict1("uncheckedDepends", Marker.val)
    ns := HxNamespace(LocalNamespaceInit(env, repo, nsVers, nsOpts, null))
    ns.libs // force sync load

    // update in-memory lookup tables
    this.nsRef.val   = ns
    this.mapRef.val  = acc.toImmutable
    this.packRef.val = updatePack(ns, acc)

    // if this is initialization, then we are done
    if (init) return ns

    // notify runtime
    this.rt.onLibsModified(ns)

    // rewrite the libs.txt file
    toWrite := Str[,]
    acc.each |x| { if (x.basis == myBasis) toWrite.add(x.name) }
    writeLibNames(toWrite.sort)

    return ns
  }

  private Void updateBootLibs(Str:HxLib acc)
  {
    // add in boot libs (sys only)
    bootLibNames.each |n|
    {
      acc[n] = HxLib(updateVersion(n), RuntimeLibBasis.boot)
    }
  }

  private Void updateSysLibs(Str:HxLib acc)
  {
    // add in system libs if I am not a sys
    if (isSys) return
    rt.sys.libs.list.each |lib|
    {
      acc[lib.name] = lib
    }
  }

  private Void updateConfiguredLibs(Str:HxLib acc)
  {
    // add in my libs from ns/libs.txt (always reload from disk)
    readLibNames.each |n|
    {
      if (acc[n] != null) return
      acc[n] = HxLib(updateVersion(n), myBasis)
    }
  }

  private Void updateProjLib(Str:HxLib acc)
  {
    // add in special "proj" lib if I am a proj
    if (rt.isProj)
    {
      ver := FileLibVersion.makeProj(tb.dir, rt.sys.info.version)
      acc["proj"] = HxLib(ver, RuntimeLibBasis.boot)
    }
  }

  private Void updateAdds(Str:HxLib acc, Str[]? names)
  {
    if (names == null || names.isEmpty) return

    names.each |name|
    {
      // check if already enabled
      dup := acc[name]
      if (dup != null) throw ArgErr("Lib already enabled: $name [$dup.basis]")

      // find latest version and add with my basis
      ver := repo.latest(name)

      acc[name] = HxLib(ver, myBasis)
    }

    // verify depends will be met (either from curent or what we are adding)
    unmet := LibDepend[,]
    names.each |name|
    {
      unmet.clear
      acc[name].ver.depends.each |d|
      {
        x := acc[d.name]
        if (x == null || !d.versions.contains(x.ver.version)) unmet.add(d)
      }
      if (!unmet.isEmpty)
        throw DependErr("Cannot add '$name', missing depends: " +unmet.join(", "))
    }
  }

  private Void updateRemoves(Str:HxLib acc, Str[]? names)
  {
    if (names == null || names.isEmpty) return

    names.each |name|
    {
      x := acc[name]

      // ignore names not found
      if (x == null) return

      // check basis
      if (x.basis != myBasis)
      {
        if (x.basis.isBoot) throw CannotRemoveBootLibErr("Cannot remove boot lib: $name")
        throw CannotRemoveSysLibErr("Proj cannot remove sys lib: $name")
      }

      // remove it
      acc.remove(name)
    }

    // check we are not removing libs that are required for remaining libs
    unmet := LibDepend[,]
    acc.each |remaining|
    {
      unmet.clear
      remaining.ver.depends.each |d|
      {
        x := acc[d.name]
        if (x == null || !d.versions.contains(x.ver.version)) unmet.add(d)
      }
      if (!unmet.isEmpty)
        throw DependErr("Removing '$unmet.first.name' breaks depends for '$remaining.name'")
    }
  }

  private LibVersion updateVersion(Str name)
  {
    repo.latest(name, false) ?: FileLibVersion.makeNotFound(name)
  }

  private RuntimeLibPack updatePack(Namespace ns, Str:HxLib allLibs)
  {
    // find my pack libs in namespace depend order
    packLibs := Lib[,]
    ns.libs.each |lib|
    {
      // always skip proj lib
      if (lib.name == XetoUtil.projLibName) return

      // only want my own
      hx := allLibs[lib.name]
      isPack := this.isSys || hx.basis.isProj
      if (!isPack) return

      // add to our pack
      packLibs.add(lib)
    }

    // compute digest using sort order
    digest := Crypto.cur.digest("SHA-1")
    packLibs.dup.sort.each |x|
    {
      digest.updateAscii(x.name)
      digest.updateAscii(x.version.toStr)
    }

    return RuntimeLibPack(digest.digest.toBase64Uri, packLibs)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const AtomicRef nsRef := AtomicRef()
  private const AtomicRef mapRef := AtomicRef()
  private const Lock lock := Lock.makeReentrant

}

**************************************************************************
** HxLib
**************************************************************************

const class HxLib : RuntimeLib
{
  internal new make(FileLibVersion ver, RuntimeLibBasis basis)
  {
    this.ver       = ver
    this.basis     = basis
    this.isSysOnly = ver.isSysOnly || isSysOnlyName(ver.name)
  }

  static Bool isSysOnlyName(Str n)
  {
    if (n == "hx")   return true
    if (n == "axon") return true
    if (n == "sys")  return true
    if (n.startsWith("sys.")) return true
    return false
  }

  override Str name() { ver.name }
  override const RuntimeLibBasis basis
  override const Bool isSysOnly
  const FileLibVersion ver

  override Str toStr() { "$name [$basis] $ver.version" }
}

