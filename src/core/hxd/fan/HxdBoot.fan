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

  ** List of lib names which are required to be installed.
  **
  Str[] requiredLibs := [
    "ph",
    "phScience",
    "phIoT",
    "phIct",
    "hx",
    "axon",
    "hxdApi",
    "hxdHttp",
    "hxdUser"
  ]

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  ** Initialize an instance of HxdRuntime but do not start it
  HxdRuntime init()
  {
    initArgs
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
}

**************************************************************************
** RunCli
**************************************************************************

** Run command
internal class RunCli : HxCli
{
  override Str name() { "run" }

  override Str summary() { "Run the daemon server" }

  @Arg { help = "Runtime database directory" }
  File? dir

  override Int run()
  {
    boot := HxdBoot { it.dir = this.dir }
    boot.run
    return 0
  }
}

