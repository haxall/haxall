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
const mixin HxRuntime
{
  ** Programatic name of the runtime. This string is always a valid tag name.
  abstract Str name()

  ** Runtime version
  abstract Version version()

  ** Platform hosting the runtime
  abstract HxPlatform platform()

  ** Namespace of definitions
  abstract Namespace ns()

  ** Folio database for this runtime
  abstract Folio db()

  ** Lookup a library by name
  abstract HxLib? lib(Str name, Bool checked := true)

  ** Library managment
  abstract HxRuntimeLibs libs()

  ** Lookup a observable for this runtime.
  abstract Observable? observable(Str name, Bool checked := true)

  ** List the published observables for this runtime
  abstract Observable[] observables()

  ** Block until currently queued background processing completes
  abstract This sync(Duration? timeout := 30sec)

  ** Has the runtime has reached steady state.  Steady state is reached
  ** after a configurable wait period elapses after the runtime is
  ** fully loaded.  This gives internal services time to spin up before
  ** interacting with external systems.
  abstract Bool isSteadyState()

  ** Public HTTP or HTTPS URI of this host.  This is always
  ** an absolute URI such 'https://acme.com/'
  abstract Uri siteUri()

  ** URI on this host to the Haystack HTTP API.  This is always
  ** a host relative URI which end withs a slash such '/api/'.
  abstract Uri apiUri()

  ** User and authentication managment
  abstract HxRuntimeUsers users()

  ** Construct a runtime specific context for the given user account
  abstract HxContext makeContext(HxUser user)
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

**************************************************************************
** HxRuntimeUsers
**************************************************************************

**
** Haxall runtime user management APIs
**
const mixin HxRuntimeUsers
{
  ** Lookup a user by username.  If not found then raise
  ** exception or return null based on the checked flag.
  abstract HxUser? read(Obj username, Bool checked := true)

  ** Authenticate a web request and return a context.  If request
  ** is not authenticated then redirect to login page and return null.
  abstract HxContext? authenticate(WebReq req, WebRes res)

  ** Create synthetic user.  The tags arg may be a dict or a map.
  abstract HxUser makeSyntheticUser(Str username, Obj? tags := null)
}


