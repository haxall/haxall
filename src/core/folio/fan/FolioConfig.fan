//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Sep 2016  Brian Frank  Creation
//

using concurrent
using xeto
using haystack

**
** FolioConfig specifies initialization constants
**
const class FolioConfig
{
  ** It-block constructor
  new make(|This| f)
  {
    f(this)
    dir = dir.normalize
    if (log == null) log = Log.get(dir.name)
    if (pool == null) pool = ActorPool { it.name = "Folio-$dir.name" }
    if (idPrefix != null) Ref("test").toAbs(idPrefix)
    isReplica = opts.has("replica")
  }

  ** Name for this database
  const Str name := "db"

  ** Home directory for this database
  const File dir

  ** Logging for this database
  const Log log

  ** Ref prefix to make internal refs absolute.  This prefix
  ** must include a trailing colon such as "p:project:r:"
  const Str? idPrefix

  ** Actor pool to use for threading
  const ActorPool pool

  ** Additional options
  const Dict opts := Etc.emptyDict

  ** Is the replica flag configured
  @NoDoc const Bool isReplica

  ** Is the given id considered an external ref based on this project's prefix
  @NoDoc Bool isExtern(Ref ref)
  {
    if (ref.isRel) return false
    if (idPrefix != null && ref.id.startsWith(idPrefix)) return false
    if (ref.id.startsWith("nav:")) return false
    return true
  }

  ** Dump to stdout
  @NoDoc Void dump()
  {
    echo("FolioConfig")
    echo("  name     = $name")
    echo("  dir      = $dir")
    echo("  log      = $log")
    echo("  idPrefix = $idPrefix")
    echo("  pool     = $pool.name")
    echo("  opts     = $opts")
  }
}

