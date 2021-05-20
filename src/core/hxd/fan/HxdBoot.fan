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
  ** Runtime version
  Version version := typeof.pod.version

  ** Runtime database dir (must set before booting)
  File? dir

  ** Initialize an instance of HxdRuntime but do not start it
  HxdRuntime init()
  {
    initArgs
    initDatabase
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

  private Void initArgs()
  {
    // validate and normalize dir
    if (dir == null) throw ArgErr("Must set 'dir' field")
    if (!dir.isDir) dir = dir.uri.plusSlash.toFile
    dir = dir.normalize
    if (!dir.exists) throw ArgErr("Dir does not exist: $dir")
    if (!dir.plus(`db/folio.index`).exists) throw ArgErr("Dir missing database files: $dir")
  }

  private Void initDatabase()
  {
    config := FolioConfig
    {
      it.name = "haxall"
      it.dir  = this.dir + `db/`
      it.pool = ActorPool { it.name = "Hxd-Folio" }
    }
    this.db = HxFolio.open(config)
  }

  internal Log log := Log.get("hxd")
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

