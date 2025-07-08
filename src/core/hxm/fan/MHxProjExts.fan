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
** HxProjExts implementation
**
const class MHxProjExts : Actor, HxProjExts
{
  new make(MHxProj proj, Str[] required) : super(proj.extActorPool)
  {
    this.proj      = proj
    this.required  = required
    this.actorPool = this.pool

listRef.val = HxExt[,].toImmutable
mapRef.val = Str:HxExt[:].toImmutable
  }

  const MHxProj proj

  override const ActorPool actorPool

  const Str[] required

  override HxExt[] list() { listRef.val }
  private const AtomicRef listRef := AtomicRef()

  override Bool has(Str name) { map.containsKey(name) }

  override HxExt? get(Str name, Bool checked := true)
  {
    lib := map[name]
    if (lib != null) return lib
    if (checked) throw UnknownExtErr(name)
    return null
  }
  internal Str:HxExt map() { mapRef.val }
  private const AtomicRef mapRef := AtomicRef()

  override Grid status()
  {
    gb := GridBuilder()
    gb.addCol("name").addCol("libStatus").addCol("statusMsg")
    list.each |lib|
    {
      spi := (MHxExtSpi)lib.spi
      gb.addRow([lib.name, spi.status, spi.statusMsg])
    }
    return gb.toGrid
  }

}

