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

  ** Xeto lib namespace
  abstract Namespace ns()

  ** Project spec management
  ProjSpecs specs() { shimLibs.specs }

  ** Temp shim
  abstract ShimLibs shimLibs()

  ** Namespace of definitions
  abstract DefNamespace defs()

  ** Folio database for this runtime
  abstract Folio db()

  ** Runtime level meta data stored in the `projMeta` database record
  abstract Dict meta()

  ** Library managment APIs
  abstract HxRuntimeLibs libsOld()

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
}


const mixin ShimLibs
{
  abstract Void add(Str name)
  abstract Void addAll(Str[] names)
  abstract Void remove(Str n)
  abstract Void removeAll(Str[] names)
  abstract Void clear()
  abstract Void reload()
  abstract Grid status(Dict? opts := null)
  abstract ProjSpecs specs()
}

**************************************************************************
** HxRuntimeLibs
**************************************************************************

**
** Haxall runtime library management APIs
**
const mixin HxRuntimeLibs
{
  ** List of libs currently enabled sorted by name
  abstract Ext[] list()

  ** Lookup an enabled lib by name.  If not found then
  ** return null or raise UnknownLibErr based on checked flag.
  abstract Ext? get(Str name, Bool checked := true)

  ** Check if there is an enabled lib with given name
  abstract Bool has(Str name)

  ** Enable a library in the runtime
  abstract Ext add(Str name, Dict tags := Etc.emptyDict)

  ** Disable a library from the runtime.  The lib arg may
  ** be a Ext instace, Lib definition, or Str name.
  abstract Void remove(Obj lib)

  ** Actor thread pool to use for libraries
  abstract ActorPool actorPool()

  ** Return status grid of enabled libs
  @NoDoc abstract Grid status()
}

