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
** ProjExts implementation
**
const class HxProjExts : Actor, ProjExts
{
  new make(HxProj proj, ActorPool actorPool) : super(actorPool)
  {
    this.proj      = proj
    this.actorPool = actorPool
  }

  const HxProj proj

  override const ActorPool actorPool

  Log log() { proj.log }

//////////////////////////////////////////////////////////////////////////
// Registry
//////////////////////////////////////////////////////////////////////////

  override Ext[] list() { listRef.val }
  private const AtomicRef listRef := AtomicRef()

  override Void each(|Ext| f) { list.each(f) }

  override Bool has(Str name) { map.containsKey(name) }

  override Ext? get(Str name, Bool checked := true)
  {
    ext := map[name]
    if (ext != null) return ext
    if (checked) throw UnknownExtErr(name)
    return null
  }
  internal Str:Ext map() { mapRef.val }
  private const AtomicRef mapRef := AtomicRef()

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

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  override Grid status()
  {
    gb := GridBuilder()
    gb.setMeta(Etc.dict1("projName", proj.name))
    gb.addCol("qname").addCol("libStatus").addCol("fantomType").addCol("statusMsg")
    list.each |ext|
    {
      spi := (HxExtSpi)ext.spi
      gb.addRow([ext.name, spi.status, ext.typeof.toStr, spi.statusMsg])
    }
    return gb.toGrid
  }

  override Ext add(Str name, Dict? settings := null)
  {
    if (settings != null && !settings.isEmpty)
      proj.settingsMgr.extInit(name, settings)
    proj.libs.add(name)
    return get(name)
  }

  Void init(HxBoot boot, HxNamespace ns)
  {
    map := Str:Ext[:]

    extLibs(ns).each |lib|
    {
      ext := HxExtSpi.instantiate(boot, this, lib)
      if (ext != null) map.add(ext.name, ext)
    }

    update(map)
  }

  ** called when libs add/removed while holding HxProjLibs.locks
  internal Void onLibsModified(HxNamespace ns)
  {
    oldMap   := map
    newMap   := Str:Ext[:]
    toRemove := oldMap.dup
    toAdd    := Lib[,]

    // walk thru new list of exts to keep/add/remove
    extLibs(ns).each |lib|
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
      ext := onAdded(lib)
      toStart.add(ext)
      newMap.addNotNull(lib.name, ext)
    }

    // remove any left over
    toRemove.each |ext| { onRemoved(ext) }

    // update lookup tables
    update(newMap)

    // after update now call start/ready
    if (proj.isRunning)
    {
      toStart.each |ext|
      {
        spi := (HxExtSpi)ext.spi
        spi.start
        spi.ready
        if (proj.isSteadyState) spi.steadyState
      }
    }
  }

  private Ext? onAdded(Lib lib)
  {
    ext := HxExtSpi.instantiate(null, this, lib)
    if (ext == null) return null
    spi := (HxExtSpi)ext.spi
    proj.obsRef.addExt(ext)
    return ext
  }

  private Void onRemoved(Ext ext)
  {
    proj.obsRef.removeExt(ext)
    spi := (HxExtSpi)ext.spi
    spi.unready
    spi.stop
  }

  private Lib[] extLibs(HxNamespace ns)
  {
    // build map of libs that have ext defs I should use
    ns.libs.findAll |lib|
    {
      if (lib.meta.missing("libExt")) return false
      if (!proj.isSys && proj.sys.ns.hasLib(lib.name)) return false
      return true
    }
  }

  private Void update(Str:Ext map)
  {
    // build sorted list
    list := map.vals
    list.sort |a, b| { a.name <=> b.name }

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
    this.mapRef.val = map.toImmutable
    this.webRoutesRef.val = webRoutes.toImmutable
    this.byTypeRef.clear // lazily rebuild
  }

//////////////////////////////////////////////////////////////////////////
// Conveniences
//////////////////////////////////////////////////////////////////////////

  override IConnExt? conn(Bool checked := true)   { getByType(IConnExt#,  checked) }
  override IFileExt? file(Bool checked := true)   { getByType(IFileExt#,  checked) }
  override IHisExt? his(Bool checked := true)     { getByType(IHisExt#,   checked) }
  override IIOExt? io(Bool checked := true)       { getByType(IIOExt#,    checked) }
  override IPointExt? point(Bool checked := true) { getByType(IPointExt#, checked) }
  override ITaskExt? task(Bool checked := true)   { getByType(ITaskExt#,  checked) }

}

