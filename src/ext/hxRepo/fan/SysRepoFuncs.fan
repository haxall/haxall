//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2026  Brian Frank  Creation
//

using xeto
using xetom
using haystack
using axon
using hx

**
** Core "sys.repo" axon functions which define the network API to serve
** a runtime as a remote repo.  By default the local namespace is used,
** but an extension can plugin an alternative ServerRepo.
**
@Gen
const class SysRepoFuncs
{

//////////////////////////////////////////////////////////////////////////
// Ops
//////////////////////////////////////////////////////////////////////////

  ** Ping the repo for availability and return summary metadata.
  ** See [RepoPing] for the tags a repo should report where applicable.
  @Api @Axon
  static Dict repoPing()
  {
    server.ping
  }

  ** Search the repo for libs matching the query string.  The query "*"
  ** matches all libs, otherwise a lib matches when its dotted name
  ** contains the query as a substring.  The result reports the latest
  ** version of each matching lib along with paging metadata.
  @Api @Axon
  static Dict repoSearch(Str query, Obj? limit := null, Obj? offset := null)
  {
    server.search(query, (toIntArg(limit) ?: 100).max(0), (toIntArg(offset) ?: 0).max(0))
  }

  ** List the versions available for the given lib sorted from latest
  ** to oldest.  If the lib name is unknown return an empty list.
  @Api @Axon
  static Dict[] repoVersions(Str lib, Obj? versions := null, Obj? limit := null)
  {
    server.versions(lib, toVersionsArg(versions), toIntArg(limit))
  }

  ** Download the xetolib zip file for the given lib name and version.
  ** If the lib is not available raise `UnknownLibErr`, or if the lib
  ** does not have the requested version raise `UnknownLibVersionErr`.
  @Api @Axon
  static File repoFetch(Str lib, Obj version)
  {
    server.fetch(lib, version as Version ?: Version.fromStr(version.toStr))
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Choke point to resolve the repo server for the current context:
  ** first ext which implements the RepoServer mixin including those
  ** inherited from sys, else serve the project's own namespace
  private static RepoServer server()
  {
    cx := Context.cur
    return (RepoServer?)cx.rt.exts.getByType(RepoServer#, false) ?: NamespaceRepoServer(cx.ns, cx.rt.dis)
  }

  ** Coerce Axon Number or Int arg to Int
  private static Int? toIntArg(Obj? v)
  {
    v is Number ? ((Number)v).toInt : v
  }

  ** Coerce Str or LibDependVersions arg to LibDependVersions
  private static LibDependVersions? toVersionsArg(Obj? v)
  {
    if (v == null) return null
    return v as LibDependVersions ?: LibDependVersions.fromStr(v.toStr)
  }
}

