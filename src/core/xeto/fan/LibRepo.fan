//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Creation
//

using concurrent

**
** Library repository is a database of Xeto libs.  A repository might
** provide access to multiple versions per library. This is the base class
** for `LocalRepo` and `RemoteRepo`.  Use `XetoEnv.repo` to get the VM's local
** repo used to build namespaces.  Use `XetoEnv.remoteRepos` to query configured
** cloud based repositoriesthat can be used to install to the local repo.
**
@Js
const mixin LibRepo
{
  ** Is this the local repo used to build namespaces
  abstract Bool isLocal()

  ** Is this a remote repo used to install to the local
  abstract Bool isRemote()

  ** Uri for this repo
  abstract Uri uri()

  ** Display name for this repo
  abstract Str dis()
}

**************************************************************************
** LocalRepo
**************************************************************************

**
** LocalRepo models the set of Xeto libs installed on the local machine.
** It is the authoritative source for runtime lib resolution and is target
** of install operations from one or more `RemoteRepo` instances.  A given
** XetoEnv always has exactly one LocalRepo accessed by `XetoEnv.repo`.
**
@Js
const mixin LocalRepo : LibRepo
{
  ** List the library names installed in the repository.
  abstract Str[] libs()

  ** List the verions available for given library name.  If the library is
  ** not available then raise exception or return null based on check flag.
  abstract LibVersion[]? versions(Str name, Bool checked := true)

  ** Get the info for a specific library name and version. If the given
  ** library or version is not available then raise exception or return
  ** null based on the checked flag.
  abstract LibVersion? version(Str name, Version version, Bool checked := true)

  ** Get the latest version of the library name available.  If no versions
  ** are available then raise exception or return null based on check flag.
  abstract LibVersion? latest(Str name, Bool checked := true)

  ** Get the latest version that matches the given dependency.  If no matches
  ** are available, then raise exception or return null based on check flag.
  abstract LibVersion? latestMatch(LibDepend depend, Bool checked := true)

  ** Solve the dependency graph for given list of libs and return a complete
  ** dependency graph.  Raise an exception is no solution can be computed
  ** based on the installed lib versions.
  abstract LibVersion[] solveDepends(LibDepend[] libs)

  ** Rescan repo and update any cached information
  @NoDoc abstract This rescan()
}

**************************************************************************
** RemoteRepo
**************************************************************************

**
** RemoteRepo is the abstract base class for network-accessible
** Xeto lib repositories. RemoteRepos are used to install/update to the
** local repo.  Subclasses map to specific backends such as the 'xeto.dev'
** registry or the GitHub HTTP API.
**
@Js
const mixin RemoteRepo : LibRepo
{
}

