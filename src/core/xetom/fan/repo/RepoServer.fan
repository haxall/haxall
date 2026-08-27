//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Aug 2026  Brian Frank  Creation
//

using xeto
using haystack

**
** RepoServer services the "sys.repo" lib ops with results in their
** wire format.  The network binding layers above this class; it is the
** counterpart to the HttpRepo client.  Servers plug in their own
** backend by enabling an ext which implements this mixin; the default
** is NamespaceRepoServer which serves a namespace's own libs.
**
const mixin RepoServer
{
  ** Service repoPing op
  abstract Dict ping()

  ** Service repoSearch op
  abstract Dict search(Str query, Int limit, Int offset)

  ** Service repoVersions op
  abstract Dict[] versions(Str lib, LibDependVersions? versions, Int? limit)

  ** Service repoFetch op
  abstract File fetch(Str lib, Version version)

  ** Service repoPublish op: validate, store, and index the posted
  ** xetolib zip; return the RepoLib dict of the published version
  abstract Dict publish(File file)

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Map LibVersion to a RepoLib dict.  Availability is catalog state
  ** the LibVersion model does not carry; an artifact served without a
  ** catalog is by definition available
  static Dict toRepoLib(LibVersion v, RepoLibAvailability availability := RepoLibAvailability.available, Str? availabilityMsg := null)
  {
    acc := Str:Obj[:]
    acc.ordered = true
    acc["lib"] = v.name
    acc["version"] = v.version
    acc["maturity"] = v.maturity
    acc["availability"] = availability
    acc.addNotNull("availabilityMsg", availabilityMsg)
    acc.addNotNull("doc", v.doc.isEmpty ? null : v.doc)
    acc.addNotNull("depends", v.depends(false))
    acc.addNotNull("digest", v.digest)
    acc["spec"] = Ref("sys.repo::RepoLib")
    return Etc.dictFromMap(acc)
  }

  ** Error for fetch of unknown lib name
  static ApiErr unknownLibErr(Str lib)
  {
    ApiErr(404, "sys.repo::UnknownLibErr", "Unknown lib: $lib", null, ["lib":lib])
  }

  ** Error for fetch of unknown lib version
  static ApiErr unknownLibVersionErr(Str lib, Version version)
  {
    ApiErr(404, "sys.repo::UnknownLibVersionErr", "Unknown lib version: $lib-$version", null, ["lib":lib, "version":version.toStr])
  }

  ** Error for publish to a repo which does not support it
  static ApiErr publishUnsupportedErr(Str dis)
  {
    ApiErr(501, "NotImplementedErr", "Repo does not support publish: $dis")
  }
}

**************************************************************************
** NamespaceRepoServer
**************************************************************************

**
** NamespaceRepoServer is the default RepoServer which serves the libs
** of a namespace from the local repo.  Instances are cheap throw away
** wrappers created per request.
**
const class NamespaceRepoServer : RepoServer
{
  new make(Namespace ns, Str dis) { this.ns = ns; this.dis = dis }

  ** Namespace whose libs are served
  const Namespace ns

  ** Display name reported by ping
  const Str dis

  override Dict ping()
  {
    Etc.dict2("dis", dis, "spec", Ref("sys.repo::RepoPing"))
  }

  override Dict search(Str query, Int limit, Int offset)
  {
    matches := libs.findAll |v| { query == "*" || v.name.contains(query) }
    page := offset >= matches.size ? LibVersion[,] : matches[offset ..< (offset+limit).min(matches.size)]
    return Etc.dictFromMap([
      "libs":   page.map |v->Dict| { RepoServer.toRepoLib(v) },
      "total":  matches.size,
      "limit":  limit,
      "offset": offset,
      "spec":   Ref("sys.repo::RepoSearch"),
    ])
  }

  override Dict[] versions(Str lib, LibDependVersions? versions, Int? limit)
  {
    v := served(lib)
    if (v == null) return Dict#.emptyList
    if (versions != null && !versions.contains(v.version)) return Dict#.emptyList
    if (limit != null && limit < 1) return Dict#.emptyList
    return [RepoServer.toRepoLib(v)]
  }

  override File fetch(Str lib, Version version)
  {
    v := served(lib)
    if (v == null) throw RepoServer.unknownLibErr(lib)
    if (v.version != version) throw RepoServer.unknownLibVersionErr(lib, version)
    if (!v.isSrc) return v.file
    return compileSrcLib(v)
  }

  ** A namespace repo is read-only
  override Dict publish(File file)
  {
    throw RepoServer.publishUnsupportedErr(dis)
  }

  ** Always serve the standard "lib/xeto" zip.  If a source lib has not
  ** been built yet, build it to that standard location and serve it.
  ** Packaging requires the include/publish patterns from the lib.xeto
  ** pragma, so building is the only correct way to zip a source dir.
  private File compileSrcLib(LibVersion v)
  {
    zipFile := XetoUtil.srcToLibZip(v)
    if (zipFile.exists) return zipFile

    ((MEnv)ns.env).build([v])

    if (!zipFile.exists) throw Err("Build did not produce zip: $v.name [$zipFile.osPath]")
    return zipFile
  }

  ** Lib versions served from this namespace
  private LibVersion[] libs()
  {
    ns.versions.findAll |v| { isServed(v) }.sort
  }

  ** Map lib name to its served version in this namespace
  private LibVersion? served(Str name)
  {
    v := ns.version(name, false)
    return v != null && isServed(v) ? v : null
  }

  ** Serve libs which loaded ok, stripping the companion lib; the status
  ** check also covers not-found shims which can never load
  private Bool isServed(LibVersion v)
  {
    !v.isCompanion && ns.libStatus(v.name, false)?.isOk == true
  }
}

