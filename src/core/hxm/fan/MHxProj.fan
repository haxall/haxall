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

**
** HxProj implementation
**
const class MHxProj : HxProj
{
  new make(HxBoot boot)
  {
    this.name         = boot.name
    this.id           = Ref("p:$name", name)
    this.dir          = boot.dir
    this.meta         = boot.meta
    this.ns           = boot.ns
    this.db           = boot.db
    this.extActorPool = ActorPool { it.name = "$this.name-ExtPool" }
    this.exts         = MHxProjExts(this, boot.requiredLibs)
  }


  const override Str name
  const override Ref id
  const override Dict meta
  const override File dir
  const override HxNamespace ns
  const override Folio db
  const override HxProjExts exts
  const ActorPool extActorPool
  override final Str toStr() { name }
}

