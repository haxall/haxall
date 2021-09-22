//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//

using concurrent
using web
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

  ** Runtime version
  abstract Version version()

  ** Platform hosting the runtime
  abstract HxPlatform platform()

  ** Runtime project directory.  It the root directory of all project
  ** oriented operational files.  The folio database is stored under
  ** this directory in a sub-directory named 'db/'.
  abstract File dir()

  ** Namespace of definitions
  abstract Namespace ns()

  ** Folio database for this runtime
  abstract Folio db()

  ** Runtime level meta data stored in the `projMeta` database record
  abstract Dict meta()

  ** Lookup a library by name.  Convenience for 'libs.get'.
  abstract HxLib? lib(Str name, Bool checked := true)

  ** Library managment APIs
  abstract HxRuntimeLibs libs()

  ** Service registry
  abstract HxServiceRegistry services()

  ** Block until currently queued background processing completes
  abstract This sync(Duration? timeout := 30sec)

  ** Has the runtime has reached steady state.  Steady state is reached
  ** after a configurable wait period elapses after the runtime is
  ** fully loaded.  This gives internal services time to spin up before
  ** interacting with external systems.  See `docHaxall::Runtime#steadyState`.
  abstract Bool isSteadyState()

  ** Construct a runtime specific context for the given user account
  abstract HxContext makeContext(HxUser user)

  ** Configuration options defined at bootstrap
  @NoDoc abstract Dict bootConfig()
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
  abstract HxLib[] list()

  ** Lookup an enabled lib by name.  If not found then
  ** return null or raise UnknownLibErr based on checked flag.
  abstract HxLib? get(Str name, Bool checked := true)

  ** Check if there is an enabled lib with given name
  abstract Bool has(Str name)

  ** Enable a library in the runtime
  abstract HxLib add(Str name, Dict tags := Etc.emptyDict)

  ** Disable a library from the runtime.  The lib arg may
  ** be a HxLib instace, Lib definition, or Str name.
  abstract Void remove(Obj lib)

  ** Actor thread pool to use for libraries
  abstract ActorPool actorPool()
}


