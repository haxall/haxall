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

//////////////////////////////////////////////////////////////////////////
// Registry
//////////////////////////////////////////////////////////////////////////

  ** List of extensions currently enabled
  abstract Ext[] list()

  ** Lookup an extension by lib name.  If not found then
  ** return null or raise UnknownExtErr based on checked flag.
  abstract Ext? get(Str name, Bool checked := true)

  ** Lookup an extension by a type it implements.  If multiple extensions
  ** implement given type, then its indeterminate which is returned.  If
  ** not found then return null or raise UnknownExtErr based on checked flag.
  @NoDoc abstract Ext? getByType(Type type, Bool checked := true)

  ** Lookup all extensions that implement given type.
  @NoDoc abstract Ext[] getAllByType(Type type)

  ** Check if there is an enabled extension with given lib name
  abstract Bool has(Str name)

  ** Actor thread pool to use for extension background processing
  abstract ActorPool actorPool()

  ** Convenience for `ProjLibs.add` lib with extension settings.
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

  ** Lookup file extension
  @NoDoc abstract IFileExt? file(Bool checked := true)

  ** Lookup history extension
  @NoDoc abstract IHisExt? his(Bool checked := true)

  ** Lookup I/O extension
  @NoDoc abstract IIOExt? io(Bool checked := true)

  ** Lookup point extension
  @NoDoc abstract IPointExt? point(Bool checked := true)

  ** Lookup task extension
  @NoDoc abstract ITaskExt? task(Bool checked := true)

}

