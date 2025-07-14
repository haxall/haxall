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
abstract const class HxSys : HxProj, Sys
{
  new make(HxBoot boot) : super(boot)
  {
    this.version  = boot.version
    this.platform = boot.initPlatform
    this.config   = boot.initConfig
  }

  override const Version version

  override Sys sys() { this }

  override const Platform platform

  override const SysConfig config

  override ICryptoExt crypto() { exts.getByType(ICryptoExt#) }
  override IHttpExt http()     { exts.getByType(IHttpExt#) }
  override IUserExt user()     { exts.getByType(IUserExt#) }
  override IClusterExt? cluster(Bool checked := true) { exts.getByType(IClusterExt#, checked) }

}

