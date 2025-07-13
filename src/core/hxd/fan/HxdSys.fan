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
    this.crypto = exts.getByType(ICryptoExt#)
    this.http   = exts.getByType(IHttpExt#)
    this.user   = exts.getByType(IUserExt#)
  }

  override Sys sys() { this }

  override const ICryptoExt crypto
  override const IHttpExt http
  override const IUserExt user
  override IClusterExt? cluster(Bool checked := true) { exts.getByType(IClusterExt#, checked) }
}

