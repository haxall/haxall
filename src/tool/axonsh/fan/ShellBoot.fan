//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Dec 2025  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using hx
using hxm

**
** Bootstrap loader for ShellSys
**
class ShellBoot : HxBoot
{
  new make() : super("axonsh", Env.cur.tempDir)
  {
    this.log = Log.get("axonsh")

    this.sysInfo["type"] = SysInfoType.axonsh.name

    this.bootLibs = [
      "sys",
      "sys.api",
      "sys.comp",
      "sys.files",
      "axon",
      "hx",
      "hx.xeto",
      "hx.axonsh",
      "hx.hxd.file",
      "hx.hxd.proj",
    ]
  }

  override Folio initFolio()
  {
    config := FolioConfig
    {
      it.name = "axonsh"
      it.dir  = this.dbDir
      it.pool = ActorPool { it.name = "Shell-Folio" }
    }
    return ShellFolio(config)
  }

  ShellSys init()
  {
    ShellSys(this).init(this)
  }
}

