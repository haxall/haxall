//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//

using concurrent
using web
using xeto
using haystack
using obs
using folio

**
** HxRuntime is the top level coordinator of a Haxall server.
**
const mixin HxRuntime : HxStdServices
{
  ** Programatic name of the runtime. This string is always a valid tag name.
  abstract Str name()

  ** Display name of the runtime.
  abstract Str dis()

  ** Runtime version
  abstract Version version()

  ** Log for project level logging
  abstract Log log()

  ** Running flag.  On startup this flag transitions to true before calling
  ** ready and start on all the libraries.  On shutdown this flag transitions
  ** to false before calling unready and stop on all the libraries.
  abstract Bool isRunning()

  ** Platform hosting the runtime
  abstract HxPlatform platform()

  ** Runtime project directory.  It the root directory of all project
  ** oriented operational files.  The folio database is stored under
  ** this directory in a sub-directory named 'db/'.
  abstract File dir()

  ** Runtime level meta data stored in the `projMeta` database record
  abstract Dict meta()

  ** Folio database for this runtime
  abstract Folio db()

  ** Xeto lib namespace
  abstract Namespace ns()

  ** Project xeto library management
  abstract ProjLibs libs()

  ** Project spec management
  abstract ProjSpecs specs()

  ** Namespace of definitions
  abstract DefNamespace defs()

  ** Project extensions
  abstract ProjExts exts()

  ** Library managment APIs
  HxRuntimeLibs libsOld() { HxRuntimeLibs(this) }

  ** Service registry
  abstract HxServiceRegistry services()

  ** Block until currently queued background processing completes
  abstract This sync(Duration? timeout := 30sec)

  ** Has the runtime has reached steady state.  Steady state is reached
  ** after a configurable wait period elapses after the runtime is
  ** fully loaded.  This gives internal services time to spin up before
  ** interacting with external systems.  See `docHaxall::Runtime#steadyState`.
  abstract Bool isSteadyState()

  ** Configuration options defined at bootstrap
  @NoDoc abstract HxConfig config()

** TODO
abstract Void recompileDefs()
}

**************************************************************************
** HxRuntimeLibs
**************************************************************************

** TODO: shim for old lib APIs
const class HxRuntimeLibs
{
  new make(HxRuntime rt) { this.rt = rt }

  const HxRuntime rt

  Ext[] list() { rt.exts.list }

  Ext? get(Str name, Bool checked := true) { rt.exts.get(fixName(name), checked) }

  Bool has(Str name) { rt.exts.has(fixName(name)) }

  ActorPool actorPool() { rt.exts.actorPool }

  Grid status() { rt.exts.status }

  Ext add(Str name, Dict tags := Etc.emptyDict)
  {
    echo("TODO: old lib add: $name")
    throw Err("TODO")
  }

  Void remove(Obj lib)
  {
    echo("TODO: old lib remove: $lib")
  }


  Str fixName(Str name)
  {
    "hx." + name + "::" + name.capitalize + "Ext"
  }

}

