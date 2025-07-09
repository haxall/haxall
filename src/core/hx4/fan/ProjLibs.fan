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

  ** Return status grid of project libs
  @NoDoc abstract Grid status(Bool installed := false)
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

  ** Latest version which is used by Haxall or null if not found
  abstract Version? version()

  ** Enable state of the lib
  abstract ProjLibState state()

  ** Summary documentation
  @NoDoc abstract Str doc()
}

**************************************************************************
** ProjLibState
**************************************************************************

**
** ProjLibState is install status of a ProjLib
**
enum class ProjLibState
{
  boot,
  enabled,
  notFound,
  disabled

  @NoDoc Bool isBoot() { this === boot }
}

