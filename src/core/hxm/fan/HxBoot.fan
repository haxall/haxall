//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Jul 2025  Brian Frank  Creation
//

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

  ** Logger to use for bootstrap (required)
  Log? log

  ** System version
  Version version := typeof.pod.version

  ** Xeto repo to use
  FileRepo repo := XetoEnv.cur.repo

  ** List of xeto lib names which are implicitly enabled as boot libs
  Str[] bootLibs := [,]

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

//////////////////////////////////////////////////////////////////////////
// Create
//////////////////////////////////////////////////////////////////////////

  ** Create a new project. If close is true then close the database
  ** after create and return null. Otherwise leave db open and return it.
  Folio? create(Bool close := true)
  {
    isCreate = true
    check
    this.nsfb = initNamespaceFileBase
    createNamespace(this.nsfb)
    this.db = createFolio
    initMeta
    if (close) { db.close; return null }
    else return db
  }

  ** Create namespace directory
  virtual Void createNamespace(FileBase fb)
  {
    libsTxt := "# Created $DateTime.now.toLocale\n" +  createLibs.join("\n")
    fb.write("libs.txt", libsTxt.toBuf)
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
    this.meta = initMeta
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

  ** Ensure projMeta exists and has current version
  virtual Dict initMeta()
  {
    // setup the tags we want for projMeta
    tags := ["projMeta": Marker.val, "version": version.toStr]

    // update rec and and return it
    return initRec("projMeta", db.read(Filter.has("projMeta"), false), tags)
  }

  ** Create Platform for HxSys
  virtual Platform initPlatform()
  {
    Platform(Etc.makeDict(platform.findNotNull))
  }

  ** Create SysConfig for HxSys
  virtual SysConfig initConfig()
  {
    if (config.containsKey("noAuth"))
    {
      echo("##")
      echo("## NO AUTH - authentication is disabled!!!!")
      echo("##")
    }
    return SysConfig(Etc.makeDict(config.findNotNull))
  }

  ** Create HxProj implementation
  abstract HxProj initProj()

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Ensure given record exists and has given tags
  Dict initRec(Str summary, Dict? rec, Str:Obj changes := [:])
  {
    if (rec == null)
    {
      log.info("Create $summary")
      return db.commit(Diff(null, changes, Diff.add.or(Diff.bypassRestricted))).newRec
    }
    else
    {
      changes = changes.findAll |v, n| { rec[n] != v }
      if (changes.isEmpty) return rec
      log.info("Update $summary")
      return db.commit(Diff(rec, changes)).newRec
    }
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

