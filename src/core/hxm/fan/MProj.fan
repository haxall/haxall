//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Jul 2025  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using hx
using hx4

**
** Proj implementation
**
const class MProj : Proj
{
  new make(Boot boot)
  {
    this.name         = boot.name
    this.id           = Ref("p:$name", name)
    this.dir          = boot.dir
    this.meta         = boot.meta
    this.ns           = boot.ns
    this.db           = boot.db
    this.extActorPool = ActorPool { it.name = "$this.name-ExtPool" }
    this.exts         = MProjExts(this, boot.requiredLibs)
  }


  const override Str name
  const override Ref id
  const override Dict meta
  const override File dir
  const override Namespace ns
  const override Folio db
  const override ProjExts exts
  const ActorPool extActorPool
  override final Str toStr() { name }
}

