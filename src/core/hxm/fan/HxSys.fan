//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Jul 2025  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using obs
using hx

**
** Haxall base implementation of Sys
**
const class HxSys : HxProj, Sys
{
  new make(HxBoot boot) : super(boot)
  {
    this.info   = boot.initSysInfo
    this.config = boot.initSysConfig
  }

  override Sys sys() { this }

  override Bool isSys() { true }

  override const SysInfo info

  override const SysConfig config

  override ICryptoExt crypto() { exts.getByType(ICryptoExt#) }
  override IHttpExt http()     { exts.getByType(IHttpExt#) }
  override IProjExt proj()     { exts.getByType(IProjExt#) }
  override IUserExt user()     { exts.getByType(IUserExt#) }
  override IIonExt? ion(Bool checked := true)         { exts.getByType(IIonExt#, checked) }
  override IClusterExt? cluster(Bool checked := true) { exts.getByType(IClusterExt#, checked) }

}

