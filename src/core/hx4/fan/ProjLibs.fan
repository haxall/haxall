//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    9 Jul 2025  Brian Frank  Creation
//

using xeto
using haystack

**
** Project Xeto namespace library management
**
const mixin ProjLibs
{
  ** List of Xeto libraries installed in the project
  abstract ProjLib[] list()

  ** Lookup an project library by name.  If not found then
  ** return null or raise UnknownLibErr based on checked flag.
  abstract ProjLib? get(Str name, Bool checked := true)

  ** Check if there is an enabled library with given name
  abstract Bool has(Str name)

  ** List all the libs installed
  abstract ProjLib[] installed()

  ** Convenience to add one library
  abstract Void add(Str name)

  ** Add one or more libraries to the namespace.
  ** Raise exception if a lib is not found or has a dependency error.
  abstract Void addAll(Str[] names)

  ** Convenience to remove one library
  abstract Void remove(Str name)

  ** Remove one or more libraries from the namespace.
  ** Raise exception if removing lib would cause a dependency error.
  abstract Void removeAll(Str[] names)

  ** Remove all project libs; just for testing
  @NoDoc abstract Void clear()

  ** Reload all libs from disk
  abstract Void reload()

  ** Return status grid of project libs
  @NoDoc abstract Grid status(Dict? opts := null)
}

**************************************************************************
** ProjLib
**************************************************************************

**
** Project library and install state
**
const mixin ProjLib
{
  ** Dotted library name
  abstract Str name()

  ** Is this a boot lib that cannot be uninstalled
  abstract Bool isBoot()

  ** Status of the lib
  abstract ProjLibStatus status()

  ** Lastest version in use or installed
  @NoDoc abstract Version? version()

  ** Summary documentation
  @NoDoc abstract Err? err()

  ** Summary documentation
  @NoDoc abstract Str? doc()
}

**************************************************************************
** ProjLibStatus
**************************************************************************

**
** ProjLib status
**
enum class ProjLibStatus
{
  ok,
  err,
  notFound,
  disabled

  @NoDoc Bool isOk() { this === ok }
}

