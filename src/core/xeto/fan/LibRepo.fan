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
    curRef.compareAndSet(null, Type.find("xetoEnv::LocalRepo").make)
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
  abstract LibInfo[]? versions(Str name, Bool checked := true)

  ** Get the info for a specific library name and version. If the given
  ** library or version is not available then raise exception or return
  ** null based on the checked flag.
  abstract LibInfo? lib(Str name, Version version, Bool checked := true)

  ** Rescan file system if this is a local repo
  @NoDoc
  abstract This rescan()

}

