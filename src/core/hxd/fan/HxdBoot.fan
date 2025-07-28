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

    this.sysInfo["runtime"] = SysInfoRuntime.hxd.name

    this.bootLibs = [
      "sys",
      "sys.api",
      "sys.comp",
      "sys.files",
      "axon",
      "hx",
      "hx.api",
      "hx.crypto",
      "hxd.file",
      "hxd.his",
      "hxd.proj",
      "hx.http",
      "hx.user",
      "hx.xeto",
      "hx.shell",
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

  override SysInfo initSysInfo()
  {
    initConfigLic
    return super.initSysInfo
  }

  private Void initConfigLic()
  {
    // try to load license file from lic/ if not explicitly configured
    if (sysConfig["hxLic"] != null) return
    file := dir.plus(`lic/`).listFiles.find |x| { x.ext == "trio" }
    if (file != null) sysConfig["hxLic"] = file.readAllStr
  }

//////////////////////////////////////////////////////////////////////////
// Create
//////////////////////////////////////////////////////////////////////////

  ** Create a new project on disk that can be loaded.
  Void create()
  {
    nsfb := initNamespaceFileBase
    createNamespace(nsfb)
    createProjMetaFile(nsfb)
    db := initFolio
    db.close
  }

  ** Create namespace directory
  private Void createNamespace(DiskFileBase fb)
  {
    libsTxt := "// Created $DateTime.now.toLocale\n" +  createLibs.join("\n")
    fb.write("libs.txt", libsTxt.toBuf)
  }

  ** Create projMeta in settings.trio
  private Void createProjMetaFile(DiskFileBase fb)
  {
    acc := createProjMeta.dup
    acc["id"] = HxSettingsMgr.projMetaId
    acc["projMeta"] = Marker.val
    acc["version"] = sysInfoVersion.toStr
    acc["mod"] = DateTime.nowUtc
    dict := Etc.dictFromMap(acc)

    file := fb.dir + `settings.trio`
    TrioWriter(file.out).writeDict(dict).close
  }

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  ** Initialize and kick off the runtime
  Int run()
  {
    // load project
    proj := HxdSys(this).init(this)

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
    if (noAuth) boot.sysConfig["noAuth"] = Marker.val
    return boot.run
  }
}

