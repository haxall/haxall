//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//    8 Jul 2025  Brian Frank  Redesign from HxRuntimeLibs
//

using concurrent
using xeto
using haystack
using folio

**
** Project extension management
**
const mixin ProjExts
{
  ** List of extensions currently enabled
  abstract Ext[] list()

  ** Lookup an extension by lib name.  If not found then
  ** return null or raise UnknownExtErr based on checked flag.
  abstract Ext? get(Str name, Bool checked := true)

  ** Check if there is an enabled extension with given lib name
  abstract Bool has(Str name)

  ** Actor thread pool to use for extension background processing
  abstract ActorPool actorPool()

  ** Return status grid of enabled extensions
  @NoDoc abstract Grid status()
}

