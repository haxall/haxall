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
using folio
using hx
using hx4

**
** ProjLibs implementation
**
const class MProjLibs : Actor, ProjLibs
{
  new make(MProj proj) : super(proj.actorPool)
  {
    this.proj = proj
  }

  const MProj proj

  override ProjLib[] list() { listRef.val }
  private const AtomicRef listRef := AtomicRef()

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

