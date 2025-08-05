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
** Runtime extension management
**
const mixin RuntimeExts
{

//////////////////////////////////////////////////////////////////////////
// Registry
//////////////////////////////////////////////////////////////////////////

  ** List all extensions (including those inherited from sys)
  abstract Ext[] list()

  ** List only my own exts (excluding those inherited from sys)
  abstract Ext[] listOwn()

  ** Iterate all extensions (including those inherited from sys)
  abstract Void each(|Ext| f)

  ** List only my own extensions (excluding those inherited from sys)
  abstract Void eachOwn(|Ext| f)

  ** Lookup an extension by lib name (including those inherited from sys).
  ** If not found then return null or raise UnknownExtErr based on checked flag.
  abstract Ext? get(Str name, Bool checked := true)

  ** Lookup an extension by lib name (excluding those inherited from sys).
  ** If not found then return null or raise UnknownExtErr based on checked flag.
  abstract Ext? getOwn(Str name, Bool checked := true)

  ** Return if extension is enabled (including those inherited from sys)
  abstract Bool has(Str name)

  ** Return if extension is enabled (excluding those inherited from sys)
  abstract Bool hasOwn(Str name)

  ** Lookup an extension by a type it implements (including those inherited from
  ** sys).  If multiple extensions implement given type, then its indeterminate
  ** which is returned.  If not found then return null or raise UnknownExtErr
  ** based on checked flag.
  @NoDoc abstract Ext? getByType(Type type, Bool checked := true)

  ** Lookup all extensions that implement given type (including those
  ** inherited from sys)
  @NoDoc abstract Ext[] getAllByType(Type type)

  ** Map of web route names to extension web modules
  @NoDoc abstract Str:ExtWeb webRoutes()

  ** Actor thread pool to use for extension background processing
  abstract ActorPool actorPool()

  ** Convenience for `RuntimeLibs.add` lib with extension settings.
  ** If the library does not define an extension then the library is
  ** still added, but this method raises an exception.
  abstract Ext add(Str name, Dict? settings := null)

  ** Return status grid of enabled extensions
  @NoDoc abstract Grid status()

//////////////////////////////////////////////////////////////////////////
// IExts
//////////////////////////////////////////////////////////////////////////

  ** Lookup connector extension
  @NoDoc abstract IConnExt? conn(Bool checked := true)

  ** Lookup history extension
  @NoDoc abstract IHisExt? his(Bool checked := true)

  ** Lookup I/O extension
  @NoDoc abstract IIOExt? io(Bool checked := true)

  ** Lookup point extension
  @NoDoc abstract IPointExt? point(Bool checked := true)

  ** Lookup task extension
  @NoDoc abstract ITaskExt? task(Bool checked := true)

}

