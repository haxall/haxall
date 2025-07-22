//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Creation
//

using concurrent

**
** Library repository is a database of Xeto libs.  A repository
** might provide access to multiple versions per library.  Use
** 'XetoEnv.repo' to get the VMs default repo.
**
@Js
const mixin LibRepo
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

  ** Rescan file system if this is a local repo
  @NoDoc abstract This rescan()


}

