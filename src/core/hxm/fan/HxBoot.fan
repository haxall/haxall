//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Jul 2025  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using hx
using xetoc

**
** Haxall project bootstrap is used to create or boot a project
**
abstract class HxBoot
{

//////////////////////////////////////////////////////////////////////////
// Configuration
//////////////////////////////////////////////////////////////////////////

  ** Are we running create or load
  Bool isCreate { private set }

  ** Are we running create or load
  Bool isLoad() { !isCreate }

  ** Project name (required)
  Str? name { set { checkLock; &name = it } }

  ** Project directory (required)
  File? dir { set { checkLock; &dir = it } }

  ** Actor pool for project threads (folio uses its own)
  ActorPool? actorPool { set { checkLock; &actorPool = it } }

  ** Logger to use for bootstrap (required)
  Log? log

  ** Xeto repo to use
  XetoEnv xetoEnv := XetoEnv.cur

  ** List of xeto lib names which are implicitly enabled as boot libs
  Str[] bootLibs := [,]

  ** Initial values projMeta (create only)
  Str:Obj? createProjMeta := [:]

  ** Initial libs for create
  Str[] createLibs := [
     "hx.xeto"
  ]

  ** List all the core libs required for basic Ion user interface
  Str[] ionLibs := [
    "hx.ion",
    "ion",
    "ion.actions",
    "ion.card",
    "ion.inputs",
    "ion.form",
    "ion.misc",
    "ion.table",
    "ion.ux",
  ]

  **
  ** SysInfo metadata
  **   - version
  **   - runtime
  **   - hostOs, hostModel, hostId?
  **   - productName, productVersion, productUri
  **   - vendorName, vendorUri
  **
  Str:Obj? sysInfo := [
    "version":        typeof.pod.version.toStr,
    "hostOs":         hostOs,
    "hostModel":      "Haxall (${Env.cur.os})",
    "productName":    "Haxall",
    "productVersion": typeof.pod.version.toStr,
    "productUri":     `https://haxall.io/`,
    "vendorName":     "SkyFoundry",
    "vendorUri":      `https://skyfoundry.com/`,
  ]

  ** Lookup sys version
  Version sysInfoVersion() { Version.fromStr(sysInfo.getChecked("version")) }

  **
  ** SysInfo config tags used to customize the system.
  ** This dict is available via Proj.config.
  ** Standard keys:
  **   - noAuth: Marker to disable authentication and use superuser
  **   - test: Marker for HxTest runtime
  **   - platformSpi: Str qname for hxPlatform::PlatformSpi class
  **   - platformSerialSpi: Str qname for hxPlatformSerial::PlatformSerialSpi class
  **   - hxLic: license Str or load from lic/xxx.trio
  **
  Str:Obj? sysConfig := [:]

//////////////////////////////////////////////////////////////////////////
// Create
//////////////////////////////////////////////////////////////////////////

  ** Create a new project on disk that can be loaded.
  Void create()
  {
    isCreate = true
    check
    this.nsfb = initNamespaceFileBase
    createNamespace(this.nsfb)
    createProjMetaFile(this.nsfb)
    this.db = createFolio
    db.close
  }

  ** Create namespace directory
  virtual Void createNamespace(DiskFileBase fb)
  {
    libsTxt := "// Created $DateTime.now.toLocale\n" +  createLibs.join("\n")
    fb.write("libs.txt", libsTxt.toBuf)
  }

  ** Create projMeta in settings.trio
  virtual Void createProjMetaFile(DiskFileBase fb)
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

  ** Create folio, routes to initFolio by default
  virtual Folio createFolio()
  {
    initFolio
  }

//////////////////////////////////////////////////////////////////////////
// Load
//////////////////////////////////////////////////////////////////////////

  ** Load the project but do not start it
  HxProj load()
  {
    isCreate = false
    check
    this.nsfb = initNamespaceFileBase
    this.db   = initFolio
    return initProj.init(this)
  }

//////////////////////////////////////////////////////////////////////////
// Check
//////////////////////////////////////////////////////////////////////////

  ** Check inputs and raise exception
  virtual Void check()
  {
    if (checked) return
    checkName
    checkDir
    checkLog
    checkActorPool
    checked = true
  }

  ** Check name if valid project name
  virtual Void checkName()
  {
    if (name == null) throw Err("Must set name")
    HxUtil.checkProjName(name)
  }

  ** Check dir is configured and normalized
  virtual Void checkDir()
  {
    if (dir == null) throw Err("Must set dir")
    if (!dir.isDir) dir = dir.uri.plusSlash.toFile
    dir = dir.normalize
    if (isCreate)
    {
      if (dir.exists) throw ArgErr("Dir already exists: $dir")
    }
    else
    {
      if (!dir.exists) throw ArgErr("Dir does not exist: $dir")
    }
  }

  ** Check log is configured
  virtual Void checkLog()
  {
    if (log == null) throw Err("Must set log")
  }

  ** Initialize actorPool
  virtual Void checkActorPool()
  {
    if (actorPool == null) actorPool = ActorPool { it.name = "Proj-$this.name" }
  }

//////////////////////////////////////////////////////////////////////////
// Steps
//////////////////////////////////////////////////////////////////////////

  ** Init file base used to manage the lib namespace
  virtual DiskFileBase initNamespaceFileBase()
  {
    nsDir := this.dir + `ns/`
    if (isLoad && !nsDir.exists) throw Err("Lib ns dir not found: $nsDir.osPath")
    return DiskFileBase(nsDir)
  }

  ** Open project folio database
  abstract Folio initFolio()

  ** Create Platform for HxSys
  virtual SysInfo initSysInfo()
  {
    meta := Etc.dictFromMap(sysInfo.findNotNull)
    return SysInfo(meta)
  }

  ** Create SysConfig for HxSys
  virtual SysConfig initSysConfig()
  {
    if (sysConfig.containsKey("noAuth"))
    {
      echo("##")
      echo("## NO AUTH - authentication is disabled!!!!")
      echo("##")
    }

    meta := Etc.dictFromMap(sysConfig.findNotNull)
    return SysConfig(meta)
  }

  ** Create settings database for project
  virtual Folio initSettingsFolio()
  {
    config := FolioConfig
    {
      it.name     = "settings"
      it.opts     = Etc.dict1("fileName", "settings.trio")
      it.dir      = this.dir + `ns/`
      it.log      = this.log
      it.pool     = this.actorPool
    }
    return FolioFlatFile.open(config)
  }

  ** Create HxProj implementation
  abstract HxProj initProj()

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Default hostOS sysMeta
  static Str hostOs()
  {
    env := Env.cur.vars
    return env["os.name"] + " " + env["os.arch"] + " " + env["os.version"]
  }

  ** Check lock ensures that key fields cannot be changed after validation
  private Void checkLock()
  {
    if (checked) throw ArgErr("Cannot change field after validation")
  }

//////////////////////////////////////////////////////////////////////////
// Internal Fields
//////////////////////////////////////////////////////////////////////////

  private Bool checked   // check
  FileBase? nsfb         // initNamespaceFileBase
  Folio? db              // initFolio
  Dict? meta             // initMeta
}

