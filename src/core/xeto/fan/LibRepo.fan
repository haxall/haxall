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

  ** Programmatic name for this repo.  Name is always a valid tag name.
  ** The name "local" is reserved for the LocalRepo instance.
  abstract Str name()

  ** Uri for this repo
  abstract Uri uri()

  ** Metadata for repo
  abstract Dict meta()

  ** Perform search request on the repo
  abstract LibRepoSearchRes search(LibRepoSearchReq req)
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
  ** Ping the remote repo and return metadata; if not reachable raise an
  ** exception or return null based on checked flag.
  abstract Dict? ping(Bool checked := true)

  ** Directory in the path where this repo is configured.
  @NoDoc abstract File pathDir()
}

**************************************************************************
** RemoteRepoRegistry
**************************************************************************

**
** RemoteRepoRegistry manages the configured remote lib repositories
** for a given XetoEnv.  RemoteRepos must be configure with a programmatic name
** and URI before use.  By default they are stored in "etc/xeto/config.props"
** using the props "repo.{name}.*".
**
@Js
const mixin RemoteRepoRegistry
{
  ** Get the default repo (always first in list if available)
  abstract RemoteRepo? def(Bool checked := true)

  ** List configured repos sorted by name, but first is always default
  abstract RemoteRepo[] list()

  ** Get remote repo by name
  abstract RemoteRepo? get(Str name, Bool checked := true)

  ** Get remote repo by URI
  abstract RemoteRepo? getByUri(Uri uri, Bool checked := true)

  ** Add a new repo to the registry.  The name must a valid tag name.
  ** Options:
  **   - pathDir: dir in XetoEnv.path as alternative to workDir for configuration
  abstract RemoteRepo add(Str name, Uri uri, Dict meta, Dict? opts := null)

  ** Remove an existing repo from registry. By default this operation will
  ** only remove a repo configured in the workDir (use anyPathkDir to remove
  ** from any dir in XetoEnv.path).
  ** Options:
  **   - anyPathDir: marker tag to remove from any dir in path
  abstract Void remove(Str name, Dict? opts := null)
}

**************************************************************************
** RemoteRepoSearchReq
**************************************************************************

**
** LibRepoSearchReq encapsulates `LibRepo.search` request
**
@Js
const class LibRepoSearchReq
{
  ** Constructor with just query string
  new make(Str query) { this.query = query }

  ** Query string
  const Str query

  ** Debug string
  override Str toStr() { query }
}

**************************************************************************
** LibRepoSearchRes
**************************************************************************

**
** LibRepoSearchRes encapsulates `LibRepo.search` response
**
@Js
const class LibRepoSearchRes
{
}

