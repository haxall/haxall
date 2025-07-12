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

  const Log log := Log.get("projExts") // TODO

  override const ActorPool actorPool

  override Ext[] list() { listRef.val }
  private const AtomicRef listRef := AtomicRef()

  override Bool has(Str qname) { map.containsKey(qname) }

  override Ext? get(Str qname, Bool checked := true)
  {
    ext := map[qname]
    if (ext != null) return ext
    if (checked) throw UnknownExtErr(qname)
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

  Void init()
  {
    map := Str:Ext[:]

    // walk all the namespace libs
    ns := proj.ns
    ns.libs.each |lib|
    {
      ext := MExtSpi.instantiate(this, lib)
      if (ext != null) map.add(ext.qname, ext)
    }

    // build lookup tables
    list := map.vals
    list.sort |a, b| { a.qname <=> b.qname }

    // save lookup tables
    this.listRef.val = list.toImmutable
    this.mapRef.val = map.toImmutable
  }
}

