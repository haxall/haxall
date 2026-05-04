//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Mar 2023  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using hx
using hxm

**
** ShellSys implements a limited, single-threaded runtime for the shell.
**
const class ShellSys : HxSys, Proj
{
  new make(ShellBoot boot) : super(boot)
  {
    this.companion = HxCompanion(this)
  }

  override final Sys sys() { this }

  override final Bool isProj() { true }

  override File varDir() { this.dir }

  override const ProjCompanion companion

}

