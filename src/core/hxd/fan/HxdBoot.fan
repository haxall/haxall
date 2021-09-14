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

  ** Name of the runtime, if omitted it defaults to dir.name
  Str? name

  ** Runtime database dir (must set before booting)
  File? dir

  ** Flag to create a new database if it doesn't already exist
  Bool create := false

  ** Logger to use for bootstrap
  Log log := Log.get("hxd")

  **
  ** Platform meta:
  **   - logoUri: URI to an SVG logo image
  **   - noAuth: Marker to disable authentication and use superuser
  **   - productName: Str name for about op
  **   - productVersion: Str version for about op
  **   - productUri: Uri to product home page
  **   - vendorName: Str name for about op
  **   - vendorUri: Uri to vendor home page
  **
  Str:Obj? platform := [:]

  **
  ** Tags define in the projMeta singleton record
  **
  Dict projMeta := Etc.emptyDict

  **
  ** List of lib names which are required to be installed.
  **
  Str[] requiredLibs := [
    "ph",
    "phScience",
    "phIoT",
    "phIct",
    "hx",
    "obs",
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
    if (rt != null) return rt
    initArgs
    initPlatform
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

    if (platform.containsKey("noAuth"))
    {
      echo("##")
      echo("## NO AUTH - authentication is disabled!!!!")
      echo("##")
    }
  }

  private Void initPlatform()
  {
    platformRef = HxPlatform(Etc.makeDict(platform.findNotNull))
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
    // setup the tags we want for projMeta
    tags := ["projMeta": Marker.val, "version": version.toStr]
    projMeta.each |v, n| { tags[n] = v }

    // update rec and set back to projMeta field so HxdRuntime can init itself
    projMeta = initRec("projMeta", db.read(Filter.has("projMeta"), false), tags)
  }

  private Void initLibs()
  {
    requiredLibs.each |libName| { initLib(libName) }
  }

  private Void initLib(Str name)
  {
    tags := ["ext":name, "dis":"lib:$name"]
    initRec("lib [$name]", db.read(Filter.eq("ext", name), false), tags)
  }

  private Dict initRec(Str summary, Dict? rec, Str:Obj changes := [:])
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

//////////////////////////////////////////////////////////////////////////
// Internal Fields
//////////////////////////////////////////////////////////////////////////

  internal Folio? db
  internal HxdRuntime? rt
  internal HxPlatform? platformRef
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
    if (noAuth) boot.platform["noAuth"] = Marker.val
    return boot.run
  }
}

