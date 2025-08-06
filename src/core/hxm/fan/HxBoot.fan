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
using hxUtil
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
  Bool isSysLoad() { !isCreate }

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
  **   - version (without patch number)
  **   - type
  **   - hostOs, hostModel, hostId?
  **   - productName, productVersion, productUri
  **   - vendorName, vendorUri
  **   - licProduct?
  **
  Str:Obj? sysInfo := [
    "version":        typeof.pod.version.segments[0..2].join("."),
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
  **   - test: Marker for HxTest runtime
  **   - noAuth: Marker to disable authentication and use superuser
  **   - safeMode: don't start exts (SkySpark only)
  **   - apiExtWeb: fantom type qname for ApiExt ExtWeb
  **   - platformSpi: Str qname for hxPlatform::PlatformSpi class
  **   - platformSerialSpi: Str qname for hxPlatformSerial::PlatformSerialSpi class
  **   - newProjExts: comma separated list of project exts
  **   - hxLic: license Str or load from lic/xxx.trio
  **
  Str:Obj? sysConfig := [:]

  ** Lookup sys config noAuth flag
  Bool isNoAuth() { sysConfig["noAuth"] != null }

  ** Lookup sys config safeMode flag
  Bool isSafeMode() { sysConfig["safeMode"] != null }

  ** Lookup syc config test flag
  Bool isTest() { sysConfig["test"] != null }

//////////////////////////////////////////////////////////////////////////
// Check
//////////////////////////////////////////////////////////////////////////

  ** Check inputs and raise exception if problems
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

  ** Create TextBase under "{dir}/ns/" to manage namespace settings via plain text
  virtual TextBase initTextBase()
  {
    TextBase(this.dir + `ns/`)
  }

  ** Open project folio database
  abstract Folio initFolio()

  ** Create SysInfo instance from sysInfo (sys boot only)
  virtual SysInfo initSysInfo()
  {
    meta := Etc.dictFromMap(sysInfo.findNotNull)
    return SysInfo(meta)
  }

  ** Create SysConfig instance from sysConfig (sys boot only)
  virtual SysConfig initSysConfig()
  {
    if (isNoAuth)
    {
      echo("##")
      echo("## NO AUTH - authentication is disabled!!!!")
      echo("##")
    }

    if (isSafeMode)
    {
      echo("##")
      echo("## SAFE MODE - proj extensions disabled!!!!")
      echo("##")
    }

    meta := Etc.dictFromMap(sysConfig.findNotNull)
    return SysConfig(meta)
  }

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
}

