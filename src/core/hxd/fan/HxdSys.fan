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

const class HxdSys : HxRuntime, Sys, Proj
{
  new make(HxdBoot boot) : super(boot)
  {
    this.info   = boot.initSysInfo
    this.config = boot.initSysConfig
  }

  override final Sys sys() { this }

  override final Bool isSys() { true }

  override final Bool isProj() { true }

  override const SysInfo info

  override const SysConfig config

  override ProjSpecs specs() { libsRef.specs }
}

