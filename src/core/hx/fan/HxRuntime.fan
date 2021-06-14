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
using folio

**
** HxRuntime is the top level coordinator of a Haxall server.
**
const mixin HxRuntime
{
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

  ** Core "hx" lib supported by all runtimes
  abstract HxCoreLib core()

  ** Public HTTP or HTTPS URI of this host
  abstract Uri httpUri()

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

  ** Find the library which implements the given Fantom type
  abstract HxLib? getType(Type type, Bool checked := true)

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
}


