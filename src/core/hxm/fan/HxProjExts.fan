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
  new make(Proj proj, ActorPool actorPool) : super(actorPool)
  {
    this.proj      = proj
    this.actorPool = actorPool
  }

  const Proj proj

  override const ActorPool actorPool

  Log log() { proj.log }

//////////////////////////////////////////////////////////////////////////
// Registry
//////////////////////////////////////////////////////////////////////////

  override Ext[] list() { listRef.val }
  private const AtomicRef listRef := AtomicRef()

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
// TODO: optimize this
    list.findAll { it.typeof.fits(type) }
  }

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
    proj.libs.add(name)
    // TODO settings
    return get(name)
  }

  Void init()
  {
    map := Str:Ext[:]

    // walk all the namespace libs
    ns := proj.ns
    ns.libs.each |lib|
    {
// TODO: skip sys libs that are system exts
if (!proj.isSys)
{
  x := proj.sys.ns.lib(lib.name, false)
  if (x != null) return
}
      ext := HxExtSpi.instantiate(this, lib)
      if (ext != null) map.add(ext.name, ext)
    }

    update(map)
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

