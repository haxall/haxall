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
using hx4

**
** ProjExts implementation
**
const class MProjExts : Actor, ProjExts
{
  new make(HxRuntime proj, ActorPool actorPool) : super(actorPool)
  {
    this.proj      = proj
    this.actorPool = actorPool
  }

  const HxRuntime proj

  override const ActorPool actorPool

  override Ext[] list() { listRef.val }
  private const AtomicRef listRef := AtomicRef()

  override Bool has(Str name) { map.containsKey(name) }

  override Ext? get(Str name, Bool checked := true)
  {
    lib := map[name]
    if (lib != null) return lib
    if (checked) throw UnknownExtErr(name)
    return null
  }
  internal Str:Ext map() { mapRef.val }
  private const AtomicRef mapRef := AtomicRef()

  override Grid status()
  {
    gb := GridBuilder()
    gb.addCol("qname").addCol("libStatus").addCol("statusMsg")
    list.each |ext|
    {
      //spi := (MExtSpi)ext.spi
      //gb.addRow([ext.qname, spi.status, spi.statusMsg])
    }
    return gb.toGrid
  }

  Void init(ExtDef[] defs)
  {
    map := Str:Ext[:]
    defs.each |def|
    {
      try
      {
        // instantiate the HxExt
        settings := Etc.dict0
//        ext := MExtSpi.instantiate(proj, def, settings)
//        map.add(ext.qname, ext)
      }
      catch (Err e)
      {
//        proj.log.err("Cannot init ext: $def.qname", e)
      }
    }

    // build lookup tables
    list := map.vals
    list.sort |a, b| { a.name <=> b.name }

    // save lookup tables
    this.listRef.val = list.toImmutable
    this.mapRef.val = map.toImmutable
  }
}

