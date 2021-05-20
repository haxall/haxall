//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//

using concurrent
using haystack
using folio

**
** HxRuntime is the top level coordinator of a Haxall server.
**
abstract const class HxRuntime
{
  ** Runtime version
  abstract Version version()

  ** Namespace of definitions
  abstract Namespace ns()

  ** Folio database for this runtime
  abstract Folio db()

  ** List of libs currently enabled
  abstract HxLib[] libs()

  ** Lookup an enabled lib by name.  If not found then
  ** return null or raise UnknownLibErr based on checked flag.
  abstract HxLib? lib(Str name, Bool checked := true)

  ** Check if there is an enabled lib with given name
  abstract Bool hasLib(Str name)

  ** Enable a library in the runtime
  abstract HxLib libAdd(Lib def, Dict tags := Etc.emptyDict)

  ** Disable a library from the runtime.  The lib arg may
  ** be a HxLib instace, Lib definition, or Str name.
  abstract Void libRemove(Obj lib)

  ** Actor thread pool to use for libraries
  abstract ActorPool libActorPool()
}

