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
** Runtime Xeto namespace library management
**
const mixin RuntimeLibs
{
  ** Xeto environment used to manage/cache Xeto libraries
  abstract XetoEnv env()

  ** List of Xeto libraries installed in the project
  abstract RuntimeLib[] list()

  ** Lookup an project library by name.  If not found then
  ** return null or raise UnknownLibErr based on checked flag.
  abstract RuntimeLib? get(Str name, Bool checked := true)

  ** Check if there is an enabled library with given name
  abstract Bool has(Str name)

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

  ** List all the libs installed
  @NoDoc abstract RuntimeLib[] installed()

  ** List of the project-only libs excluding the special "proj" lib
//  @NoDoc abstract Lib[] projLibs()

  ** Hash of all the project-only libs excluding the special "proj" lib
//  @NoDoc abstract Str projLibsDigest()

  ** Return status grid of project libs
  @NoDoc abstract Grid status(Dict? opts := null)
}

**************************************************************************
** ProjLib
**************************************************************************

**
** Runtime library and install state
**
const mixin RuntimeLib
{
  ** Dotted library name
  abstract Str name()

  ** Basis is the source origin of the library
  abstract RuntimeLibBasis basis()

  ** Status of the lib
  abstract RuntimeLibStatus status()

  ** Lastest version in use or installed
  @NoDoc abstract Version? version()

  ** Summary documentation
  @NoDoc abstract Err? err()

  ** Summary documentation
  @NoDoc abstract Str? doc()
}

**************************************************************************
** RuntimeLibStatus
**************************************************************************

**
** RuntimeLib status enum
**
enum class RuntimeLibStatus
{
  ok,
  err,
  notFound,
  disabled

  @NoDoc Bool isOk() { this === ok }
}

**************************************************************************
** RuntimeLibBasis
**************************************************************************

**
** RuntimeLibBasis defines owner of a given library
**
enum class RuntimeLibBasis
{
  ** System level boot library
  boot,

  ** System level library
  sys,

  ** Project level library
  proj,

  ** Library installed, but not enabled
  disabled

  @NoDoc Bool isBoot() { this === boot }
  @NoDoc Bool isSys()  { this === sys }
  @NoDoc Bool isProj() { this === proj }
}

