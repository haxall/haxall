//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Jul 2025  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack
using folio
using hx
using hxUtil
using xetoc

**
** HxBoot is base class for bootstrap of all HxRuntimes.
** It is the base class of HxSysBoot and HxProjBoot.
**
abstract class HxBoot
{

//////////////////////////////////////////////////////////////////////////
// Initialization
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
    this.name  = name
    this.dir   = dir
    this.dbDir = dir + `db/`
    this.nsDir = dir + `ns/`
    this.actorPool = ActorPool { it.name = "Rt-$this.name" }
  }

//////////////////////////////////////////////////////////////////////////
// Configuration
//////////////////////////////////////////////////////////////////////////

  ** Project name
  const Str name

  ** Runtime directory
  const File dir

  ** Runtime db/ directory
  const File dbDir

  ** Runtime ns/ directory
  const File nsDir

  ** Actor pool for runtime threads
  ActorPool actorPool

  ** Logger to use for bootstrap/runtime
  Log log := Log.get("boot")

  ** Xeto repo to use for building namespace
  XetoEnv xetoEnv := XetoEnv.cur

  ** Xeto lib names implicitly enabled as boot libs (sys only)
  Str[] bootLibs := [,]

  ** List all the core libs required for basic Ion user interface,
  ** or empty list if ion is not installed
  Str[] ionLibs()
  {
    if (Pod.find("ion", false) == null) return Str#.emptyList
    return [
      "sys.template",
      "hx.ion",
      "ion",
      "ion.actions",
      "ion.card",
      "ion.doc",
      "ion.editor",
      "ion.form",
      "ion.inputs",
      "ion.misc",
      "ion.styles",
      "ion.table",
      "ion.tool",
      "ion.ux",
    ]
  }

  ** Lookup sys version
  abstract Version sysInfoVersion()

  ** Get tag from sysConfig
  abstract Obj? sysConfigGet(Str name)

  ** Extension settings overrides keyed by lib name such "hx.http".  This
  ** is a dict that is merged into the settings stored on disk (it does *not*
  ** change what is stored on disk (used only for testing).
  Str:Dict extSettingsOverrides := [:]

  ** Lookup sysConfig noAuth flag
  Bool isNoAuth() { sysConfigGet("noAuth") != null }

  ** Lookup sysConfig safeMode flag
  Bool isSafeMode() { sysConfigGet("safeMode") != null }

  ** Lookup sysConfig test flag
  Bool isTest() { sysConfigGet("test") != null }

//////////////////////////////////////////////////////////////////////////
// Hooks
//////////////////////////////////////////////////////////////////////////

  ** Initalize runtime meta
  virtual HxMeta initMeta(HxRuntime rt)
  {
    // define expected tags
    expect := Str:Obj[:]
    expect["version"] = sysInfoVersion.toStr
    if (rt.isProj) expect["projMeta"] = Marker.val

    // lookup current meta rec
    db := rt.db
    rec := HxUtil.readMetaRec(rt.db, false)

    // create or update if necessary
    if (rec == null)
    {
      tags := expect.dup.set("rt", "meta")
      rec = db.commit(Diff(null, tags, Diff.add.or(Diff.bypassRestricted))).newRec
    }
    else if (!expect.all |v, n| { rec[n] == v })
    {
      rec = db.commit(Diff(rec, expect, Diff.bypassRestricted)).newRec
    }

    return HxMeta(rt, rec)
  }

  ** Open folio database for runtime
  abstract Folio initFolio()

  ** Init hooks for Folio database
  virtual HxFolioHooks initFolioHooks(HxRuntime rt)
  {
    HxFolioHooks(rt)
  }

  ** Create background manager
  virtual HxBackgroundMgr initBackgroundMgr(HxRuntime rt)
  {
    HxBackgroundMgr(rt, isTest)
  }

  ** Create library manager
  virtual HxLibs initLibs(HxRuntime rt)
  {
    HxLibs(rt, this)
  }

  ** Create library manager
  virtual HxExts initExts(HxRuntime rt)
  {
    HxExts(rt, rt.actorPool)
  }

  ** Create watch manager
  virtual HxWatches initWatches(HxRuntime rt)
  {
    HxWatches(rt)
  }

  ** Create observable manager
  virtual HxObservables initObs(HxRuntime rt)
  {
    HxObservables(rt)
  }

}

**************************************************************************
** HxProjBoot
**************************************************************************

**
** HxProjBoot is base class for bootstrap of multi-tenant Proj runtimes
**
abstract class HxProjBoot : HxBoot
{
  ** Constructor
  new make(Sys sys, Str name, File dir) : super(name, dir) { this.sysRef = sys }

  ** Parent Sys instance
  virtual Sys sys() { sysRef }
  const Sys sysRef

  ** Lookup sys version
  override Version sysInfoVersion() { sys.info.version }

  ** Get tag from sysConfig
  override Obj? sysConfigGet(Str name) { sys.config.get(name) }
}

**************************************************************************
** HxSysBoot
**************************************************************************

**
** HxSysBoot is base class for bootstrap of HxSys runtimes
**
abstract class HxSysBoot : HxBoot
{

  ** Constructor
  new make(Str name, File dir) : super(name, dir)
  {
    // special initialization
    if (Env.cur.vars["HX_DEV_MODE"] == "true")
      sysConfig["devMode"] = Marker.val
  }

//////////////////////////////////////////////////////////////////////////
// Main
//////////////////////////////////////////////////////////////////////////

  ** Init from a command line main using standardized args:
  **   - noAuth: disable auth for loopback and auto-login with superuser
  **   - safeMode: disable all project extensions
  **   - console: run interactive console after boot
  This initOpts(AbstractMain main)
  {
    if (hasBoolOpt(main, "noAuth"))   sysConfig["noAuth"] = Marker.val
    if (hasBoolOpt(main, "safeMode")) sysConfig["safeMode"] = Marker.val
    if (hasBoolOpt(main, "console"))  sysConfig["console"] = Marker.val
    return this
  }

  ** Does given main have the bool option field name and is it set
  Bool hasBoolOpt(AbstractMain main, Str name)
  {
    field := main.typeof.field(name, false)
    if (field == null || field.type !== Bool#) return false
    return field.get(main)
  }

//////////////////////////////////////////////////////////////////////////
// Config
//////////////////////////////////////////////////////////////////////////

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
    "hostOs":         HxUtil.hostOs,
    "hostModel":      "Haxall (${Env.cur.os})",
    "productName":    "Haxall",
    "productVersion": typeof.pod.version.toStr,
    "productUri":     `https://haxall.io/`,
    "vendorName":     "SkyFoundry",
    "vendorUri":      `https://skyfoundry.com/`,
  ]

  **
  ** SysConfig meta to build Sys.config:
  **   - test: Marker for HxTest runtime
  **   - devMode: Marker for devMode mode (initialize via env var HX_DEV_MODE)
  **   - safeMode: Marker to disable all project extensions
  **   - noAuth: Marker to disable auth for loopback and auto-login with superuser
  **   - console: Marker to run interactive console after boot
  **   - apiExtWeb: qname for ApiExt ExtWeb class
  **   - platformSpi: qname for hxPlatform::PlatformSpi class
  **   - platformNetworkSpi: qname for hxPlatformNetwork::PlatformNetworkSpi class
  **   - platformSerialSpi: qname for hxPlatformSerial::PlatformSerialSpi class
  **   - platformTimeSpi: qname for hxPlatformTime::PlatformTimeSpi class
  **   - hxLic: license Str or load from lic/xxx.trio
  **   - ephemeralHttpPort: Marker to let OS assign HTTP port
  **
  ** SkySpark options:
  **   - safeMode: don't start exts (SkySpark only)
  **   - newProjExts: comma separated list of project exts
  **   - demogenMaxDays: Number of days to limit for smaller devices
  **   - undefs: comma separated list of symbols to remove from ns
  **   - defFuncs: Marker to load funcs into DefNamespace (disabled otherwise)
  **
  Str:Obj? sysConfig := [:]

  ** Lookup sys version
  override Version sysInfoVersion() { Version.fromStr(sysInfo.getChecked("version")) }

  ** Get tag from sysConfig if booting Sys or from projSys if booting Proj
  override Obj? sysConfigGet(Str name) { sysConfig.get(name) }

//////////////////////////////////////////////////////////////////////////
// Hooks
//////////////////////////////////////////////////////////////////////////

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
      echo("## NO AUTH - authentication is disabled on loopback!")
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

  ** Create console
  virtual HxConsole initConsole(Sys sys)
  {
    HxmConsole(sys)
  }

//////////////////////////////////////////////////////////////////////////
// Init+Run
//////////////////////////////////////////////////////////////////////////

  ** Initialize the system (to use standard run).
  ** Raise NotSetupErr to route to notSetup handling.
  abstract HxSys init()

  ** Standardized init and run
  virtual Int run()
  {
    // init system
    HxSys? sys := null
    try
      sys = init
    catch (NotSetupErr e)
      return notSetup(e)

    // install shutdown handler
    Env.cur.addShutdownHook(sys.shutdownHook)

    // start system
    sys.start

    // wait until HttpExt is opened and assigned port
    /*
    http := sys.ext("hx.http", false) as IHttpExt
    if (http != null)
    {
      try
        httpReady(http.waitUntilListening(30sec).httpPort)
      catch (Err e)
        e.trace
    }
    */

    // run console or sleep forever
    if (sys.config.has("console"))
      return sys.console.run
    else
      Actor.sleep(Duration.maxVal)
    return 0
  }

  ** Handle not setup error
  virtual Int notSetup(NotSetupErr e)
  {
    echo("ERROR: system is not setup - $e.msg")
    return 1
  }

  ** Callback when HTTP port is opened
  virtual Void httpReady(Int? port) {}
}

