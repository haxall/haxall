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
** for [LocalRepo] and [RemoteRepo].  Use [XetoEnv.repo] to get the VM's local
** repo used to build namespaces.  Use [XetoEnv.remoteRepos] to query configured
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
}

**************************************************************************
** LocalRepo
**************************************************************************

**
** LocalRepo models the set of Xeto libs installed on the local machine.
** It is the authoritative source for runtime lib resolution and is target
** of install operations from one or more [RemoteRepo] instances.  A given
** XetoEnv always has exactly one LocalRepo accessed by [XetoEnv.repo].
**
@Js
const mixin LocalRepo : LibRepo
{
  ** List all libraries installed in the local repository.
  abstract LibVersion[] libs()

  ** Lookup a library by name.
  abstract LibVersion? lib(Str name, Bool checked := true)

  ** Resolve the dependency graph for given list of libs and return a
  ** complete dependency graph.  Raise an exception is no solution can be
  ** computed based on the installed lib versions.
  abstract LibVersion[] resolveDepends(LibDepend[] libs)

  ** Resolve a library by its name and check its version contraints
  @NoDoc abstract LibVersion? depend(LibDepend d, Bool checked := true)

  ** Rescan repo and update any cached information
  @NoDoc abstract This rescan()
}

**************************************************************************
** RemoteRepo
**************************************************************************

**
** RemoteRepo is the abstract base class for network-accessible
** Xeto lib repositories. RemoteRepos are used to install/update to the
** local repo.  Subclasses map to specific backends such as the `xeto.dev`
** registry or the GitHub HTTP API.
**
** A RemoteRepo is only the named configuration for a repo; all network
** activity happens through a connected [RemoteRepoSession].
**
@Js
const mixin RemoteRepo : LibRepo
{
  ** Open a connected session to this remote repo.  The default session
  ** authenticates each request with the configured bearer token, or
  ** anonymously when none is configured.  The session is owned by the
  ** caller who must close it when complete.
  abstract RemoteRepoSession open()

  ** Return if an env var name if auth token is configured for this repo
  @NoDoc abstract Str? authTokenEnvName()

  ** Directory in the path where this repo is configured.
  @NoDoc abstract File pathDir()
}

**************************************************************************
** RemoteRepoSession
**************************************************************************

**
** RemoteRepoSession is a connected session to a [RemoteRepo].  The repo
** is the named configuration; the session is the connection: it owns
** the authentication state for its lifetime and its method surface
** mirrors the "sys.repo" wire operations.  Sessions are owned by the
** caller: open one for a batch of calls and close it when complete.
**
@Js
abstract class RemoteRepoSession
{
  ** Repo this session is connected to
  abstract RemoteRepo repo()

  ** Ping the remote repo and return metadata; if not reachable raise an
  ** exception or return null based on checked flag.
  abstract Dict? ping(Bool checked := true)

  ** Perform search request on the remote repo
  abstract RemoteRepoSearchRes search(RemoteRepoSearchReq req)

  ** Get the info for a specific library name and version. If the given
  ** library or version is not available then raise exception or return
  ** null based on the checked flag.
  abstract LibVersion? version(Str name, Version version, Bool checked := true)

  ** List the verions available for given library name. The library versions
  ** are sorted from latest to oldest.  If the library is not available always
  ** return empty list.
  **
  ** Options:
  **   - limit: max number to return
  **   - versions: constraints as LibDependVersions instance
  abstract LibVersion[] versions(Str name, Dict? opts := null)

  ** Get the latest version of the library name available.  If no versions
  ** are available then raise exception or return null based on check flag.
  abstract LibVersion? latest(Str name, Bool checked := true)

  ** Get the latest version that matches the given dependency.  If no matches
  ** are available, then raise exception or return null based on check flag.
  abstract LibVersion? latestMatch(LibDepend depend, Bool checked := true)

  ** Download the xetolib zip for given name and version
  abstract Buf fetch(Str name, Version version)

  ** Publish a xetolib zip file to the repo and return its published
  ** version.  Requires authentication with publish permission.  Repos
  ** which do not support publishing raise UnsupportedErr.
  virtual LibVersion publish(File file) { throw UnsupportedErr("Repo does not support publish: $repo.name") }

  ** Close the session and release any resources
  virtual Void close() {}
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

  ** Save an authentication token to fan.props for the given remote name
  ** or remote type. Return the env var name which is always formatted
  ** as "XETO_REPO_{name}".  If token is null, then the remove the token
  abstract Str saveAuthToken(Str name, Str? token)
}

**************************************************************************
** RemoteRepoSearchReq
**************************************************************************

**
** RemoteRepoSearchReq encapsulates [RemoteRepo.search] request
**
@Js
const class RemoteRepoSearchReq
{
  ** Constructor with query string and it-block
  new make(Str query, |This|? f := null)
  {
    this.query = query
    if (f != null) f(this)
  }

  ** Query string
  const Str query

  ** Requested limit (server may response with smaller limit)
  const Int limit := 100

  ** Debug string
  override Str toStr() { query }

  ** Default implementation of match - simple contains for now
  @NoDoc Bool matches(LibVersion lib)
  {
    if (query == "*") return true
    return lib.name.contains(query)
  }
}

**************************************************************************
** RemoteRepoSearchRes
**************************************************************************

**
** RemoteRepoSearchRes encapsulates [RemoteRepo.search] response
**
@Js
const mixin RemoteRepoSearchRes
{
  ** Matching libs with following data:
  **   - name
  **   - version (latest by default)
  **   - doc
  abstract LibVersion[] libs()

  ** Total count of matches
  abstract Int total()

  ** Actual limit used by remote server
  abstract Int limit()

  ** Offset for this page of results in the total
  abstract Int offset()
}

@NoDoc @Js
const class MRemoteRepoSearchRes : RemoteRepoSearchRes
{
  new make(|This| f) { f(this) }
  override const LibVersion[] libs
  override const Int total
  override const Int limit
  override const Int offset
}

