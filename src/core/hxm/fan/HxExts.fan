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
const class HxExts : RuntimeExts
{
  new make(HxRuntime rt, ActorPool actorPool)
  {
    this.rt        = rt
    this.actorPool = actorPool
  }

  const HxRuntime rt

  override const ActorPool actorPool

  Log log() { rt.log }

  virtual HxExtSpi makeSpi(HxExtSpiInit init) { HxExtSpi(init) }

//////////////////////////////////////////////////////////////////////////
// Registry
//////////////////////////////////////////////////////////////////////////

  HxExtRegistry registry() { registryRef.val }
  private const AtomicRef registryRef := AtomicRef()

  override Ext[] list() { registry.list }

  override Ext[] listOwn() { registry.listOwn }

  override Void each(|Ext| f) { registry.each(f) }

  override Void eachOwn(|Ext| f) { registry.eachOwn(f) }

  override Bool has(Str name) { registry.has(name) }

  override Bool hasOwn(Str name) { registry.hasOwn(name)  }

  override Ext? get(Str name, Bool checked := true) { registry.get(name, checked) }

  override Ext? getOwn(Str name, Bool checked := true) {registry.getOwn(name, checked) }

  override Ext? getByType(Type type, Bool checked := true) { registry.getByType(type, checked) }

  override Ext[] getAllByType(Type type) { registry.getAllByType(type) }

  override Str:ExtWeb webRoutes() { registry.webRoutes }

  override ExtWeb webIndex() { registry.webIndex }

  override Grid status(Dict? opts := null) { registry.status(opts) }

//////////////////////////////////////////////////////////////////////////
// Modifications
//////////////////////////////////////////////////////////////////////////

  override Ext add(Str name, Dict? settings := null)
  {
    ((HxLibs)rt.libs).addExt(name, settings)
    return get(name)
  }

  Void init(HxBoot boot, HxNamespace ns)
  {
    map := Str:Ext[:]
    HxExtRegistry.eachExtLib(rt) |lib|
    {
      ext := HxExtSpi.instantiate(boot, this, lib)
      if (ext != null) map.add(ext.name, ext)
    }
    update(map)
  }

  ** called when libs add/removed while holding HxProjLibs.lock
  internal Void onNamespaceModified(HxNamespace ns)
  {
    oldMap   := Str:Ext[:]
    newMap   := Str:Ext[:]
    toAdd    := Lib[,]

    // build map of my old extensions
    listOwn.each |ext| { oldMap[ext.name] = ext }
    toRemove := oldMap.dup

    // walk thru new list of exts to keep/add/remove
    HxExtRegistry.eachExtLib(rt) |lib|
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
    registryRef.val = HxExtRegistry(rt, map)
  }
}


**************************************************************************
** HxExtRegistry
**************************************************************************

const class HxExtRegistry
{
  static Void eachExtLib(Runtime rt, |Lib| f)
  {
    // build map of my libs that have an ext
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

      f(lib)
    }
  }

  new make(Runtime rt, Str:Ext map)
  {
    // if I am proj, then merge in sys exts
    if (!rt.isSys) rt.sys.exts.list.each |sysExt| { map[sysExt.name] = sysExt }

    // build sorted list
    list := map.vals
    list.sort |a, b| { a.name <=> b.name }
    listOwn := list.findAll { it.rt === rt }

    // map web routes
    webRoutes := Str:ExtWeb[:]
    webIndex := list.first.web
    list.each |ext|
    {
      web := ext.web
      routeName := web.routeName
      if (routeName.isEmpty || web.isUnsupported) return
      if (webRoutes[routeName] != null) rt.log.warn("Duplicte ext routes: $routeName")
      webRoutes[routeName] = web
      if (web.indexPriority > webIndex.indexPriority) webIndex = web
    }

    // save lookup tables
    this.rt        = rt
    this.list      = list
    this.listOwn   = listOwn
    this.map       = map
    this.webRoutes = webRoutes
    this.webIndex  = webIndex
  }

  const Runtime rt

  const Ext[] list

  const Ext[] listOwn

  const Str:Ext map

  const Str:ExtWeb webRoutes

  const ExtWeb webIndex

  private const ConcurrentMap byTypeRef := ConcurrentMap()

  Void each(|Ext| f) { list.each(f) }

  Void eachOwn(|Ext| f) { listOwn.each(f) }

  Bool has(Str name) { get(name, false) != null }

  Bool hasOwn(Str name) { getOwn(name, false) != null  }

  Ext? get(Str name, Bool checked := true)
  {
    ext := map[name]
    if (ext != null) return ext
    if (checked) throw UnknownExtErr(name)
    return null
  }

  Ext? getOwn(Str name, Bool checked := true)
  {
    ext := map[name]
    if (ext != null && ext.rt === this.rt) return ext
    if (checked) throw UnknownExtErr(name)
    return null
  }

  Ext? getByType(Type type, Bool checked := true)
  {
    ext := getAllByType(type).first
    if (ext != null) return ext
    if (checked) throw UnknownExtErr(type.qname)
    return null
  }

  Ext[] getAllByType(Type type)
  {
    cached := byTypeRef.get(type)
    if (cached != null) return cached

    res := list.findAll { it.typeof.fits(type) }.toImmutable
    if (!res.isEmpty) byTypeRef.set(type, res)
    return res
  }

  Grid status(Dict? opts := null)
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
    gb.addCol("name").addCol("libBasis").addCol("extStatus").addCol("fantomType").addCol("statusMsg")
    list.each |ext|
    {
      spi := ext.spi as HxExtSpi
      basis := rt.libs.get(ext.name, false)?.basis?.name
      gb.addRow([ext.name, basis, spi?.status, ext.typeof.toStr, spi?.statusMsg])
    }
    grid := gb.toGrid

    search := opts["search"] as Str
    if (search != null) grid = grid.filter(Filter.search(search))

    return grid
  }

}

