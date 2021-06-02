//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2021  Brian Frank  Creation
//

using concurrent
using util
using haystack
using folio
using hx
using hxFolio

**
** Bootstrap loader for Haxall daemon
**
class HxdBoot
{

//////////////////////////////////////////////////////////////////////////
// Configuration
//////////////////////////////////////////////////////////////////////////

  ** Runtime version
  Version version := typeof.pod.version

  ** Runtime database dir (must set before booting)
  File? dir

  ** Flag to create a new database if it doesn't already exist
  Bool create := false

  ** Logger to use for bootstrap
  Log log := Log.get("hxd")

  ** Configuration tags:
  **   - logoUri: URI to an SVG logo image
  **   - noAuth: Marker to disable authentication and use superuser
  **   - productName: Str name for about op
  **   - productVersion: Str version for about op
  **   - productUri: Uri to product home page
  **   - vendorName: Str name for about op
  **   - vendorUri: Uri to vendor home page
  Str:Obj? config := [:]

  **
  ** List of lib names which are required to be installed.
  **
  Str[] requiredLibs := [
    "ph",
    "phScience",
    "phIoT",
    "phIct",
    "hx",
    "axon",
    "hxApi",
    "hxHttp",
    "hxShell",
    "hxUser"
  ]

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  ** Initialize an instance of HxdRuntime but do not start it
  HxdRuntime init()
  {
    initArgs
    initConfig
    openDatabase
    initMeta
    initLibs
    rt = HxdRuntime(this)
    return rt
  }

  ** Initialize and kick off the runtime
  Int run()
  {
    // initialize runtime instance
    init

    // install shutdown handler
    Env.cur.addShutdownHook(rt.shutdownHook)

    // startup runtime
    rt.start
    Actor.sleep(Duration.maxVal)
    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Internals
//////////////////////////////////////////////////////////////////////////

  private Void initArgs()
  {
    // validate and normalize dir
    if (dir == null) throw ArgErr("Must set 'dir' field")
    if (!dir.isDir) dir = dir.uri.plusSlash.toFile
    dir = dir.normalize
    if (!create)
    {
      if (!dir.exists) throw ArgErr("Dir does not exist: $dir")
      if (!dir.plus(`db/folio.index`).exists) throw ArgErr("Dir missing database files: $dir")
    }

    if (config.containsKey("noAuth"))
    {
      echo("##")
      echo("## NO AUTH - authentication is disabled!!!!")
      echo("##")
    }
  }

  private Void initConfig()
  {
    addConfig("logoUri",        `/hxUser/logo.svg`)
    addConfig("productName",    "Haxall")
    addConfig("productVersion", version.toStr)
    addConfig("productUri",     `https://haxall.io/`)
    addConfig("vendorName",     "SkyFoundry")
    addConfig("vendorUri",      `https://skyfoundry.com/`)
    configDict = Etc.makeDict(config.findNotNull)
  }

  private Void addConfig(Str name, Obj val)
  {
    config.addNotNull(name, val)
  }

  private Void openDatabase()
  {
    config := FolioConfig
    {
      it.name = "haxall"
      it.dir  = this.dir + `db/`
      it.pool = ActorPool { it.name = "Hxd-Folio" }
    }
    this.db = HxFolio.open(config)
  }

  private Void initMeta()
  {
    tags := ["hxMeta":Marker.val,"projMeta": Marker.val]
    initRec("hxMeta", db.read("hxMeta", false), tags)
  }

  private Void initLibs()
  {
    requiredLibs.each |libName| { initLib(libName) }
  }

  private Void initLib(Str name)
  {
    tags := ["hxLib":name, "dis":"lib:$name"]
    initRec("lib [$name]", db.read("hxLib==$name.toCode", false), tags)
  }

  private Void initRec(Str summary, Dict? rec, Str:Obj changes := [:])
  {
    if (rec == null)
    {
      log.info("Create $summary")
      db.commit(Diff(null, changes, Diff.add.or(Diff.bypassRestricted)))
    }
    else
    {
      changes = changes.findAll |v, n| { rec[n] != v }
      if (changes.isEmpty) return
      log.info("Update $summary")
      db.commit(Diff(rec, changes))
    }
  }

//////////////////////////////////////////////////////////////////////////
// Internal Fields
//////////////////////////////////////////////////////////////////////////

  internal Folio? db
  internal HxdRuntime? rt
  internal Dict? configDict
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
    boot.run
    return 0
  }
}

