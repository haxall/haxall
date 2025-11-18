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
using folio
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
    if (rt.isProj) this.companionLib = HxLib.makeCompanion(boot.sysInfoVersion)
  }

  internal HxNamespace init()
  {
    doUpdate(HxLibUpdate { it.init = true })
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

  Folio db() { rt.db }

  HxNamespace ns()
  {
    while (needReload.val) update(HxLibUpdate {})
    return nsRef.val
  }

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

  Str? companionLibDigest() { companionLibDigestRef.val }
  private const AtomicRef companionLibDigestRef := AtomicRef()

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
    addAll([name])
  }

  override Void addAll(Str[] names)
  {
    update(HxLibUpdate { it.adds = checkDupNames(names) })
  }

  override Void remove(Str name)
  {
    removeAll([name])
  }

  override Void removeAll(Str[] names)
  {
    update(HxLibUpdate { it.removes = checkDupNames(names) })
  }

  override Void clear()
  {
    toRemove := list.findAll { it.basis == myBasis }.map { it.name }
    removeAll(toRemove)
  }

  override Void reload()
  {
    needReload.val = true
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
// Update
//////////////////////////////////////////////////////////////////////////

  internal Void addExt(Str name, Dict? settings)
  {
    update(HxLibUpdate { it.adds = [name]; it.settings = settings })
  }

  private HxNamespace update(HxLibUpdate u)
  {
    lock.lock
    try
      return doUpdate(u)
    finally
      lock.unlock
  }

  private HxNamespace doUpdate(HxLibUpdate u)
  {
    // save old namespace for thunk reuse
    oldNs := nsRef.val as MNamespace

    // build list of all the libs that should be in my namespace
    acc := Str:HxLib[:]
    updateBootLibs(acc)
    updateSysLibs(acc)
    updateConfiguredLibs(acc)
    updateCompanionLib(acc)
    updateAdds(acc, u.adds)
    updateRemoves(acc, u.removes)
    companionRecs := updateCompanionRecs(oldNs)

    // create namespace
    nsVers := acc.vals.map |x->LibVersion| { x.ver }
    nsOpts := Etc.dict2x("uncheckedDepends", Marker.val, "companionRecs", companionRecs)
    ns := HxNamespace(rt, env, nsVers, nsOpts)

    // update in-memory lookup tables
    this.nsRef.val   = ns
    this.mapRef.val  = acc.toImmutable
    this.packRef.val = updatePack(ns, acc)
    this.companionLibDigestRef.val = "companion-${rt.name}-${Ref.gen.id}"
    this.needReload.val = false

    // if this is initialization, then we are done
    if (u.init) return ns

    // persist to folio database
    commit(u)

    // notify runtime
    this.rt.onNamespaceModified(ns)

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
    // add in my libs defined by folio recs
    readLibNames.each |n|
    {
      if (acc[n] != null) return
      acc[n] = HxLib(updateVersion(n), myBasis)
    }
  }

  private Void updateCompanionLib(Str:HxLib acc)
  {
    // add in special "proj" companion lib if I am a proj
    if (companionLib != null) acc[companionLib.name] = companionLib
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

  private CompanionRecs? updateCompanionRecs(HxNamespace? oldNs)
  {
    if  (!rt.isProj) return null
    recs := rt.db.readAllList(Filter.eq("rt", "spec").or(Filter.eq("rt", "instance")))
    thunks := updateCompanionReuseThunks(recs, oldNs)
    return CompanionRecs(recs, thunks)
  }

  private Str:Thunk updateCompanionReuseThunks(Dict[] newRecs, HxNamespace? oldNs)
  {
    // gotta have old namespace
    acc := Str:Thunk[:]
    if (oldNs == null) return acc

    // build up map of old recs by name
    oldCompanionRecs := oldNs.companionRecs
    oldRecsByName := Str:Dict[:]
    oldCompanionRecs.recs.each |oldRec|
    {
      name := oldRec["name"] as Str
      if (name == null) return
      oldRecsByName[name] = oldRec
    }

    // now walk thru new records and try to reuse thunk
    oldLib := oldNs.lib(XetoUtil.companionLibName, false)
    newRecs.each |newRec|
    {
      name := newRec["name"] as Str
      if (name == null) return

      // if old rec is not match, then do not reuse
      oldRec := oldRecsByName[name]
      if (newRec !== oldRec) return

      // try to reuse from previous proj lib, but if it failed to
      // compile then fallback to the previous companionRecs cache
      if (oldLib != null)
      {
        spec := oldLib.spec(name, false)
        if (spec != null && spec.isFunc && spec.func.hasThunk)
          acc[name] = spec.func.thunk
      }
      else
      {
        acc.setNotNull(name, oldCompanionRecs.thunks.get(name))
      }
    }

    return acc
  }

  private RuntimeLibPack updatePack(Namespace ns, Str:HxLib allLibs)
  {
    // find my pack libs in namespace depend order
    packLibs := Lib[,]
    ns.libs.each |lib|
    {
      // always skip proj companion lib
      if (lib.name == XetoUtil.companionLibName) return

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
// Database
//////////////////////////////////////////////////////////////////////////

  private Str[] readLibNames()
  {
    acc := Str[,]
    recs := db.readAllList(Filter.eq("rt", "lib"))
    recs.each |rec|
    {
      acc.addNotNull(rec["name"] as Str)
    }
    return acc
  }

  private Void commit(HxLibUpdate u)
  {
    diffs := Diff[,]

    // add diffs
    u.eachAdd |n, extra| { diffs.add(addDiff(n, extra)) }

    // remove diffs
    u.eachRemove |n|
    {
      rec := db.read(Filter.eq("rt", "lib").and(Filter.eq("name", n)), false)
      if (rec == null) log.warn("Remove unknown lib: $n")
      else diffs.add(removeDiff(rec))
    }

    if (diffs.isEmpty) return
    db.commitAll(diffs)
  }

  static Diff addDiff(Str n, Dict? extra := null)
  {
    diff := Etc.dict2("rt", "lib", "name", n)
    if (extra != null) diff = Etc.dictMerge(extra, diff)
    return Diff(null, diff, Diff.add.or(Diff.bypassRestricted))
  }

  static Diff removeDiff(Dict rec)
  {
    Diff(rec, Etc.dict0, Diff.remove.or(Diff.bypassRestricted))
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const AtomicRef nsRef := AtomicRef()
  private const AtomicBool needReload := AtomicBool(true)
  private const AtomicRef mapRef := AtomicRef()
  private const Lock lock := Lock.makeReentrant
  private const HxLib? companionLib
}

**************************************************************************
** HxLibUpdate
**************************************************************************

internal class HxLibUpdate
{
  Str[]? adds     // lib names to add
  Str[]? removes  // lib names to remove
  Bool init       // initialization
  Dict? settings  // if adding extension

  Void eachAdd(|Str n, Dict? extra| f)
  {
    if (adds == null) return
    adds.each |n, i|
    {
      f(n, i == 0 ? settings : null)
    }
  }

  Void eachRemove(|Str n| f)
  {
    if (removes == null) return
    removes.each(f)
  }
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
    this.isSysOnly = ver.isHxSysOnly || isSysOnlyName(ver.name)
  }

  internal new makeCompanion(Version version)
  {
    this.ver       = FileLibVersion.makeCompanion(version)
    this.basis     = RuntimeLibBasis.boot
    this.isSysOnly = false
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

