//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2021  Brian Frank  Creation
//   13 Jul 2025  Brian Frank  Refactoring for 4.0
//

using concurrent
using web
using util
using xeto
using haystack
using folio
using hx
using hxm

const class HxdSys : HxProj, Sys
{
  new make(NewHxdBoot boot) : super(boot)
  {
    this.version = boot.version
  }

  override const Version version

  override Sys sys() { this }

  override const Platform platform := Platform(Etc.dict0) // TODO

  override const SysConfig config := SysConfig(Etc.dict0)

  override ICryptoExt crypto() { exts.getByType(ICryptoExt#) }
  override IHttpExt http()     { exts.getByType(IHttpExt#) }
  override IUserExt user()     { exts.getByType(IUserExt#) }
  override IClusterExt? cluster(Bool checked := true) { exts.getByType(IClusterExt#, checked) }
}

