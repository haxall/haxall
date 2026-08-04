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
** a runtime's own libs as a remote repo.  The ops are published by
** enabling the sys.repo lib in a project's namespace.
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
    Etc.dict2("dis", curContext.rt.dis, "spec", Ref("sys.repo::RepoPing"))
  }

  ** Search the repo for libs matching the query string.  The query "*"
  ** matches all libs, otherwise a lib matches when its dotted name
  ** contains the query as a substring.  The result reports the latest
  ** version of each matching lib along with paging metadata.
  @Api @Axon
  static Dict repoSearch(Str query, Obj? limit := null, Obj? offset := null)
  {
    cx := curContext
    max := (toIntArg(limit) ?: 100).max(0)
    off := (toIntArg(offset) ?: 0).max(0)
    matches := libs(cx).findAll |v| { query == "*" || v.name.contains(query) }
    page := off >= matches.size ? LibVersion[,] : matches[off ..< (off+max).min(matches.size)]
    return Etc.dictFromMap([
      "libs":   page.map |v->Dict| { toRepoLib(v) },
      "total":  matches.size,
      "limit":  max,
      "offset": off,
      "spec":   Ref("sys.repo::RepoSearch"),
    ])
  }

  ** List the versions available for the given lib sorted from latest
  ** to oldest.  If the lib name is unknown return an empty list.
  @Api @Axon
  static Dict[] repoVersions(Str lib, Obj? versions := null, Obj? limit := null)
  {
    cx := curContext
    v := localLib(cx, lib)
    if (v == null) return Dict#.emptyList
    opts := Str:Obj[:]
    opts.addNotNull("versions", versions)
    opts.addNotNull("limit", toIntArg(limit))
    return MRemoteRepo.findAllVersionsWithOpts([v], Etc.dictFromMap(opts)).map |x->Dict| { toRepoLib(x) }
  }

  ** Download the xetolib zip file for the given lib name and version.
  ** If the lib is not available raise `UnknownLibErr`, or if the lib
  ** does not have the requested version raise `UnknownLibVersionErr`.
  @Api @Axon
  static File repoFetch(Str lib, Obj version)
  {
    cx := curContext
    ver := version as Version ?: Version.fromStr(version.toStr)
    v := localLib(cx, lib)
    if (v == null) throw ApiErr(404, "sys.repo::UnknownLibErr", "Unknown lib: $lib", null, ["lib":lib])
    if (v.version != ver) throw ApiErr(404, "sys.repo::UnknownLibVersionErr", "Unknown lib version: $lib-$ver", null, ["lib":lib, "version":ver.toStr])
    if (!v.isSrc) return v.file
    return XetoZipUtil.srcLibZip(v).toFile(`${lib}.xetolib`)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Local repo versions for the libs in this project's namespace
  private static LibVersion[] libs(Context cx)
  {
    acc := LibVersion[,]
    cx.ns.libs.each |lib| { acc.addNotNull(cx.rt.ns.env.repo.lib(lib.name, false)) }
    return acc.sort
  }

  ** Map lib name to its local repo version if in this project's namespace
  private static LibVersion? localLib(Context cx, Str name)
  {
    cx.ns.lib(name, false) == null ? null : cx.rt.ns.env.repo.lib(name, false)
  }

  ** Map LibVersion to a RepoLib dict
  private static Dict toRepoLib(LibVersion v)
  {
    acc := Str:Obj[:]
    acc.ordered = true
    acc["lib"] = v.name
    acc["version"] = v.version
    acc.addNotNull("doc", v.doc.isEmpty ? null : v.doc)
    acc.addNotNull("depends", v.depends(false))
    if (!v.isSrc) acc["digest"] = digest(v.file)
    acc["spec"] = Ref("sys.repo::RepoLib")
    return Etc.dictFromMap(acc)
  }

  ** Digest file contents in the RepoLib.digest format
  private static Str digest(File file)
  {
    "sha256:" + file.readAllBuf.toDigest("SHA-256").toBase64Uri
  }

  ** Coerce Axon Number or Int arg to Int
  private static Int? toIntArg(Obj? v)
  {
    v is Number ? ((Number)v).toInt : v
  }

  ** Current context
  private static Context curContext() { Context.cur }
}
