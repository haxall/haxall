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
** might provide access to multiple versions per library.
**
@Js
const mixin LibRepo
{
  ** Current default repository for the VM
  static LibRepo cur()
  {
    repo := curRef.val as LibRepo
    if (repo != null) return repo
    curRef.compareAndSet(null, Type.find("xetoc::FileRepo").make)
    return curRef.val
  }
  private static const AtomicRef curRef := AtomicRef()

  ** Install the default repo only if one is not currently installed
  @NoDoc
  static Void install(LibRepo repo)
  {
    curRef.compareAndSet(null, repo)
  }

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

  ** Solve the dependency graph for given list of libs and return a complete
  ** dependency graph.  Raise an exception is no solution can be computed
  ** based on the installed lib versions.
  abstract LibVersion[] solveDepends(LibVersion[] libs)

  ** Construct a namespace for the given set of lib infos in this repo.
  ** This method does not solve the dependency graph.  The list of lib
  ** versions passed must be a complete dependency tree that satisifies
  ** all version constraints.  Also see `solveDepends`.
  //abstract LibNamespace createNamespace(LibVersion[] libs)

  ** Rescan file system if this is a local repo
  @NoDoc
  abstract This rescan()

}

