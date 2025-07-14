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
  new make(File dir) : super("sys", dir) {}

//////////////////////////////////////////////////////////////////////////
// Configuration
//////////////////////////////////////////////////////////////////////////

  ** Logging
  override Log log := Log.get("hxd")

  ** Version
  override Version version := typeof.pod.version

  **
  ** Platform meta:
  **   - logoUri: URI to an SVG logo image
  **   - productName: Str name for about op
  **   - productVersion: Str version for about op
  **   - productUri: Uri to product home page
  **   - vendorName: Str name for about op
  **   - vendorUri: Uri to vendor home page
  **
  Str:Obj? platform := [:]

  **
  ** Misc configuration tags used to customize the system.
  ** This dict is available via Proj.config.
  ** Standard keys:
  **   - noAuth: Marker to disable authentication and use superuser
  **   - test: Marker for HxTest runtime
  **   - platformSpi: Str qname for hxPlatform::PlatformSpi class
  **   - platformSerialSpi: Str qname for hxPlatformSerial::PlatformSerialSpi class
  **   - hxLic: license Str or load from lic/xxx.trio
  **
  Str:Obj? config := [:]

  ** List of xeto lib names which are required to be installed.
  override Str[] bootLibs()
  {
    [
    "sys",
    "sys.api",
    "sys.files",
    "axon",
    "hx",
    "hx.api",
    "hx.crypto",
    "hxd.proj",
    "hx.http",
    "hx.user",
    ]
  }

//////////////////////////////////////////////////////////////////////////
// HxBoot Overrides
//////////////////////////////////////////////////////////////////////////

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

  override Platform initPlatform()
  {
    Platform(Etc.makeDict(platform.findNotNull))
  }

  override SysConfig initConfig()
  {
    if (config.containsKey("noAuth"))
    {
      echo("##")
      echo("## NO AUTH - authentication is disabled!!!!")
      echo("##")
    }

    initConfigLic
    return SysConfig(Etc.makeDict(config.findNotNull))
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
    // initialize project
    proj := init

    // install shutdown handler
// TODO
//    Env.cur.addShutdownHook(proj.shutdownHook)

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
    boot := HxdBoot(dir)
    if (noAuth) boot.config["noAuth"] = Marker.val
    return boot.run
  }
}

