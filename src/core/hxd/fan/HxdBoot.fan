//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2021  Brian Frank  Creation
//

using concurrent
using web
using util
using xeto
using haystack
using folio
using hx
using hxm
using hxFolio

**
** Bootstrap loader for Haxall daemon
**
class HxdBoot : HxBoot
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make()
  {
    this.log = Log.get("hxd")
    this.bootLibs = [
      "sys",
      "sys.api",
      "sys.comp",
      "sys.files",
      "axon",
      "hx",
      "hx.api",
      "hx.crypto",
      "hxd.proj",
      "hx.http",
      "hx.user",
      "hx.xeto",
    ]
  }

//////////////////////////////////////////////////////////////////////////
// HxBoot Overrides
//////////////////////////////////////////////////////////////////////////

  override Void checkName()
  {
    if (name == null) this.name = "sys"
    else super.checkName
  }

  override Folio initFolio()
  {
    config := FolioConfig
    {
      it.name = "haxall"
      it.dir  = this.dir + `db/`
      it.pool = ActorPool { it.name = "Hxd-Folio" }
    }
    return HxFolio.open(config)
  }

  override SysConfig initConfig()
  {
    initConfigLic
    return super.initConfig
  }

  private Void initConfigLic()
  {
    // try to load license file from lic/ if not explicitly configured
    if (config["hxLic"] != null) return
    file := dir.plus(`lic/`).listFiles.find |x| { x.ext == "trio" }
    if (file != null) config["hxLic"] = file.readAllStr
  }

  override HxProj initProj()
  {
    HxdSys(this)
  }

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  ** Initialize and kick off the runtime
  Int run()
  {
    // load project
    proj := load

    // install shutdown handler
    Env.cur.addShutdownHook(proj.shutdownHook)

    // startup proj
    proj.start
    Actor.sleep(Duration.maxVal)
    return 0
  }
}

**************************************************************************
** RunCli
**************************************************************************

** Run command
internal class RunCli : HxCli
{
  override Str name() { "run" }

  override Str summary() { "Run the daemon server" }

  @Opt { help = "Disable authentication and use superuser for all access" }
  Bool noAuth

  @Arg { help = "Runtime database directory" }
  File? dir

  override Int run()
  {
    boot := HxdBoot { it.dir = this.dir }
    if (noAuth) boot.config["noAuth"] = Marker.val
    return boot.run
  }
}

