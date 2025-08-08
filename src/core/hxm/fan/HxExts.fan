//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//    8 Jul 2025  Brian Frank  Redesign from HxdRuntimeLibs
//

using concurrent
using xeto
using haystack
using folio
using hx

**
** RuntimeExts implementation
**
const class HxExts : Actor, RuntimeExts
{
  new make(HxRuntime rt) : super(rt.actorPool)
  {
    this.rt        = rt
    this.actorPool = rt.actorPool
  }

  const HxRuntime rt

  override const ActorPool actorPool

  Log log() { rt.log }

//////////////////////////////////////////////////////////////////////////
// Registry
//////////////////////////////////////////////////////////////////////////

  override Ext[] list() { listRef.val }
  private const AtomicRef listRef := AtomicRef()

  override Ext[] listOwn() { listOwnRef.val }
  private const AtomicRef listOwnRef := AtomicRef()

  override Void each(|Ext| f) { list.each(f) }

  override Void eachOwn(|Ext| f) { listOwn.each(f) }

  override Bool has(Str name) { get(name, false) != null }

  override Bool hasOwn(Str name) { getOwn(name, false) != null  }

  override Ext? get(Str name, Bool checked := true)
  {
    ext := map[name]
    if (ext != null) return ext
    if (checked) throw UnknownExtErr(name)
    return null
  }
  internal Str:Ext map() { mapRef.val }
  private const AtomicRef mapRef := AtomicRef()

  override Ext? getOwn(Str name, Bool checked := true)
  {
    ext := map[name]
    if (ext != null && ext.rt === this.rt) return ext
    if (checked) throw UnknownExtErr(name)
    return null
  }

  override Ext? getByType(Type type, Bool checked := true)
  {
    ext := getAllByType(type).first
    if (ext != null) return ext
    if (checked) throw UnknownExtErr(type.qname)
    return null
  }

  override Ext[] getAllByType(Type type)
  {
    cached := byTypeRef.get(type)
    if (cached != null) return cached

    res := list.findAll { it.typeof.fits(type) }.toImmutable
    if (!res.isEmpty) byTypeRef.set(type, res)
    return res
  }
  private const ConcurrentMap byTypeRef := ConcurrentMap()

  override Str:ExtWeb webRoutes() { webRoutesRef.val }
  private const AtomicRef webRoutesRef := AtomicRef()


  virtual HxExtSpi makeSpi(HxExtSpiInit init) { HxExtSpi(init) }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  override Grid status(Dict? opts := null)
  {
    if (opts == null) opts = Etc.dict0

    list := this.list.dup

    show := (opts["show"] as Str)?.lower ?: ""
    if (opts.has("sysOnly") || show.contains("sys"))
    {
      list = list.findAll |x| { x.rt.isSys }
    }
    else if (opts.has("projOnly") || show.contains("proj"))
    {
      list = list.findAll |x| { x.rt.isProj }
    }

    gb := GridBuilder()
    gb.setMeta(Etc.dict1("projName", rt.name))
    gb.addCol("qname").addCol("libBasis").addCol("extStatus").addCol("fantomType").addCol("statusMsg")
    list.each |ext|
    {
      spi := (HxExtSpi)ext.spi
      basis := rt.libs.get(ext.name, false)?.basis?.name
      gb.addRow([ext.name, basis, spi.status, ext.typeof.toStr, spi.statusMsg])
    }
    grid := gb.toGrid

    search := opts["search"] as Str
    if (search != null) grid = grid.filter(Filter.search(search))

    return grid
  }

//////////////////////////////////////////////////////////////////////////
// Modifications
//////////////////////////////////////////////////////////////////////////

  override Ext add(Str name, Dict? settings := null)
  {
    if (settings != null && !settings.isEmpty)
      rt.settingsMgr.extInit(name, settings)
    rt.libs.add(name)
    return get(name)
  }

  Void init(HxBoot boot, HxNamespace ns)
  {
    map := Str:Ext[:]
    findExtLibs.each |lib|
    {
      ext := HxExtSpi.instantiate(boot, this, lib)
      if (ext != null) map.add(ext.name, ext)
    }
    update(map)
  }

  ** called when libs add/removed while holding HxProjLibs.lock
  internal Void onLibsModified(HxNamespace ns)
  {
    oldMap   := Str:Ext[:]
    newMap   := Str:Ext[:]
    toRemove := oldMap.dup
    toAdd    := Lib[,]

    // build map of my old extensions
    listOwn.each |ext| { oldMap[ext.name] = ext }

    // walk thru new list of exts to keep/add/remove
    findExtLibs.each |lib|
    {
      name := lib.name
      cur  := oldMap[name]
      if (cur != null)
      {
        toRemove.remove(name)
        newMap[name] = cur
      }
      else
      {
        toAdd.add(lib)
      }
    }

    // add new ones
    toStart := Ext[,]
    toAdd.each |lib|
    {
      ext := doAdd(lib)
      if (ext == null) return
      toStart.add(ext)
      newMap.add(ext.name, ext)
    }

    // remove any left over
    toRemove.each |ext| { doRemove(ext) }

    // update lookup tables
    update(newMap)

    // after update now call start/ready
    if (rt.isRunning)
    {
      toStart.each |ext|
      {
        spi := (HxExtSpi)ext.spi
        spi.start
        spi.ready
        if (rt.isSteadyState) spi.steadyState
      }
    }
  }

  private Ext? doAdd(Lib lib)
  {
    ext := HxExtSpi.instantiate(null, this, lib)
    if (ext == null) return null
    spi := (HxExtSpi)ext.spi
    rt.obsRef.addExt(ext)
    return ext
  }

  private Void doRemove(Ext ext)
  {
    rt.obsRef.removeExt(ext)
    spi := (HxExtSpi)ext.spi
    spi.unready
    spi.stop
  }

  private Lib[] findExtLibs()
  {
    // build map of my libs that have an ext
    acc := Lib[,]
    ns := rt.ns
    rt.libs.list.each |rtLib|
    {
      // skip non-proj basis libs if I am not sys
      if (!rt.isSys && !rtLib.basis.isProj) return

      // lookup lib, skip if in error state
      lib := ns.lib(rtLib.name, false)
      if (lib == null) return

      // skip those without an extension
      if (lib.meta.missing("libExt")) return false

      acc.add(lib)
    }
    return acc
  }

  private Void update(Str:Ext map)
  {
    // if I am proj, then merge in sys exts
    if (!rt.isSys) rt.sys.exts.list.each |sysExt| { map[sysExt.name] = sysExt }

    // build sorted list
    list := map.vals
    list.sort |a, b| { a.name <=> b.name }
    listOwn := list.findAll { it.rt === this.rt }

    // map web routes
    webRoutes := Str:ExtWeb[:]
    list.each |ext|
    {
      web := ext.web
      routeName := web.routeName
      if (routeName.isEmpty || web.isUnsupported) return
      if (webRoutes[routeName] != null) log.warn("Duplicte ext routes: $routeName")
      else webRoutes[routeName] = web
    }

    // save lookup tables
    this.listRef.val = list.toImmutable
    this.listOwnRef.val = listOwn.toImmutable
    this.mapRef.val = map.toImmutable
    this.webRoutesRef.val = webRoutes.toImmutable
    this.byTypeRef.clear // lazily rebuild
  }

//////////////////////////////////////////////////////////////////////////
// Conveniences
//////////////////////////////////////////////////////////////////////////

  override IConnExt? conn(Bool checked := true)   { getByType(IConnExt#,  checked) }
  override IHisExt? his(Bool checked := true)     { getByType(IHisExt#,   checked) }
  override IIOExt? io(Bool checked := true)       { getByType(IIOExt#,    checked) }
  override IPointExt? point(Bool checked := true) { getByType(IPointExt#, checked) }
  override ITaskExt? task(Bool checked := true)   { getByType(ITaskExt#,  checked) }

}

