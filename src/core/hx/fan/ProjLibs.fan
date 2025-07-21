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
  ** Xeto environment used to manage/cache Xeto libraries
  abstract XetoEnv env()

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

  ** Hash of all the project-only libs excluding the special "proj" lib
  @NoDoc abstract Str projLibsDigest()

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

  ** Basis is the source origin of the library
  abstract ProjLibBasis basis()

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
** ProjLibBasis defines source origin
**
enum class ProjLibBasis
{
  ** System level boot library
  sysBoot,

  ** System level enabled library
  sys,

  ** Project boot library
  projBoot,

  ** Project level enabled library
  proj,

  ** System level library installed, but not being used
  disabledSys,

  ** Project level library installed, but not being used
  disabledProj

  ** Is this a boot lib
  @NoDoc Bool isBoot() { this === sysBoot || this === projBoot }

  ** Is this a system level lib
  @NoDoc Bool isSys() { this === sysBoot || this === sys || this === disabledSys }

  ** Is this a project level lib
  @NoDoc Bool isProj() { this === projBoot || this === proj || this === disabledProj }
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

