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
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(Str name, File dir)
  {
    // check name
    HxUtil.checkProjName(name)

    // check dir
    if (!dir.isDir) dir = dir.uri.plusSlash.toFile
    dir = dir.normalize

    // init fields
    this.name = name
    this.dir = dir
    this.actorPool = ActorPool { it.name = "Rt-$this.name" }
  }

//////////////////////////////////////////////////////////////////////////
// Configuration
//////////////////////////////////////////////////////////////////////////

  ** Project name
  const Str name

  ** Runtime directory
  const File dir

  ** Actor pool for runtime threads
  ActorPool actorPool

  ** Logger to use for bootstrap/runtime
  Log log := Log.get("boot")

  ** Xeto repo to use for building namespace
  XetoEnv xetoEnv := XetoEnv.cur

  ** Xeto lib names implicitly enabled as boot libs (sys only)
  Str[] bootLibs := [,]

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
  ** SysInfo metadata to build Sys.info:
  **   - version (without patch number)
  **   - type (SysInfoType enum)
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
  ** SysConfig meta to build Sys.config:
  **   - test: Marker for HxTest runtime
  **   - noAuth: Marker to disable authentication and use superuser
  **   - safeMode: don't start exts (SkySpark only)
  **   - apiExtWeb: qname for ApiExt ExtWeb class
  **   - platformSpi: qname for hxPlatform::PlatformSpi class
  **   - platformSerialSpi: qname for hxPlatformSerial::PlatformSerialSpi class
  **   - newProjExts: comma separated list of project exts
  **   - hxLic: license Str or load from lic/xxx.trio
  **
  Str:Obj? sysConfig := [:]

  ** Lookup sysConfig noAuth flag
  Bool isNoAuth() { sysConfig["noAuth"] != null }

  ** Lookup sysConfig safeMode flag
  Bool isSafeMode() { sysConfig["safeMode"] != null }

  ** Lookup sysConfig test flag
  Bool isTest() { sysConfig["test"] != null }

//////////////////////////////////////////////////////////////////////////
// Hooks
//////////////////////////////////////////////////////////////////////////

  ** Create TextBase under "{dir}/ns/" to manage namespace settings via plain text
  virtual TextBase initTextBase()
  {
    TextBase(this.dir + `ns/`)
  }

  ** Open folio database for runtime
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

}

