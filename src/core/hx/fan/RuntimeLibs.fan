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

  ** Add all the depends on given name that are not enabled.
  ** Add given name itself only if 'self' flag is true.
  @NoDoc abstract Void addDepends(Str name, Bool self)

  ** Convenience to remove one library
  abstract Void remove(Str name)

  ** Remove one or more libraries from the namespace.
  ** Raise exception if removing lib would cause a dependency error.
  abstract Void removeAll(Str[] names)

  ** Refresh the namespace based on current rt recs
  @NoDoc abstract Void refresh()

  ** Remove all project libs; just for testing
  @NoDoc abstract Void clear()

  ** Libs for xeto pack of this runtime's libs
  @NoDoc abstract RuntimeLibPack pack()

  ** List all the libs installed
  @NoDoc abstract RuntimeLib[] installed()

  ** Return status grid of project libs
  @NoDoc abstract Grid status(Dict? opts := null)
}

**************************************************************************
** RuntimeLib
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

  ** Is this a boot only lib
  @NoDoc abstract Bool isBootOnly()

  ** Is this a system only lib
  @NoDoc abstract Bool isSysOnly()
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

  @NoDoc Bool isBoot()     { this === boot }
  @NoDoc Bool isSys()      { this === sys }
  @NoDoc Bool isProj()     { this === proj }
  @NoDoc Bool isDisabled() { this === disabled }
}


**************************************************************************
** RuntimeLibPack
**************************************************************************

**
** Runtime library pack is a digest based on lib names and versions.
** It is used to build a xeto pack for browser serialization.  It includes
** my own libs with an ok status, but for project runtimes excludes sys libs
** and the special project companion lib.  It changes only when the lib
** names/versions are modified, it is *not* based on actual lib contents.
**
@NoDoc
const class RuntimeLibPack
{
  new make(Str digest, Lib[] libs)
  {
    this.digest = digest
    this.libs   = libs
  }

  ** Digest of the libs
  const Str digest

  ** Libs in dependency order
  const Lib[] libs
}

