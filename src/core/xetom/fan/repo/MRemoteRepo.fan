//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Apr 2026  Brian Frank  Creation
//

using xeto
using haystack

**
** MRemoteRepo is based class for all RemoteRepo implementations
**
@Js
abstract const class MRemoteRepo : MRepo, RemoteRepo
{
  static MRemoteRepo create(RemoteRepoInit init)
  {
    // check indexed props to match a URI to a specific fantom type:
    //    "xeto.repo": "uri qname"
    //    "xeto.repo": "http://test-1/ testXeto::TestRemoteRepo"
    typeName := findTypeForUri(init.uri.toStr)
    if (typeName == null) typeName = findTypeForUri(init.uri.plus(`/`).toStr)
    if (typeName == null) return TempRemoteRepo(init)
    return Type.find(typeName).make([init])
  }

  private static Str? findTypeForUri(Str match)
  {
    Env.cur.index("xeto.repo").eachWhile |str|
    {
      sp := str.index(" ")
      if (sp == null) return  null
      uri := str[0..<sp]
      if (uri != match) return null
      return str[sp+1..-1]
    }
  }

  new make(RemoteRepoInit init) : super(init.env)
  {
    this.name    = init.name
    this.uri     = init.uri
    this.meta    = init.meta
    this.pathDir = init.pathDir
  }

  override const Str name

  override const Uri uri

  override const Dict meta

  override const File pathDir

  override final Bool isLocal() { false }

  override final Bool isRemote() { true }

  override final Str toStr() { name }

  ** Utility to filter a list of options with opts to implement
  ** the standard LibRepo.versions behavior
  static LibVersion[] findAllVersionsWithOpts(LibVersion[]? list, Dict? opts)
  {
    // if null
    if (list == null) return LibVersion#.emptyList

    // contrainsts
    versions := XetoUtil.optVersionConstraints(opts)
    if (versions != null) list = list.findAll { versions.contains(it.version) }

    // limit
    limit := XetoUtil.optInt(opts, "limit", Int.maxVal)
    if (list.size > limit) list = list[0..<limit]
    return list
  }

  ** Default routes to versions with '{limit:1}'
  override LibVersion? latest(Str name, Bool checked := true)
  {
    opts := Etc.dict1("limit", 1)
    x := versions(name, opts).first
    if (x != null) return x
    if (checked) throw UnknownLibErr(name)
    return null
  }

  ** Default routes to versions with '{limit:1, versions:d.versions}'
  override LibVersion? latestMatch(LibDepend d, Bool checked := true)
  {
    opts := Etc.dict2("limit", 1, "versions", d.versions)
    x := versions(d.name, opts).first
    if (x != null) return x
    if (checked) throw UnknownLibErr(d.toStr)
    return null
  }

  ** Default routes to versions with '{limit:1, versions:version}'
  override LibVersion? version(Str name, Version version, Bool checked := true)
  {
    x := versions(name, Etc.dict1("versions", LibDependVersions(version))).first
    if (x != null) return x
    if (checked) throw UnknownLibErr("$name-$version")
    return null
  }
}

**************************************************************************
** TempRemoteRepo
**************************************************************************

internal const class TempRemoteRepo : MRemoteRepo
{
  new make(RemoteRepoInit init) : super(init) {}

  override Dict? ping(Bool checked := true) { throw Err("TODO") }

  override RemoteRepoSearchRes search(RemoteRepoSearchReq req) { throw Err("TODO") }

  override LibVersion[] versions(Str name, Dict? opts := null) { throw Err("TODO") }

  override Buf fetch(Str name, Version version) { throw Err("TODO") }
}

**************************************************************************
** RemoteRepoInit
**************************************************************************

@Js
const class RemoteRepoInit
{
  new make(XetoEnv e, Str n, Uri u, Dict m, File d) { env = e; name = n; uri = u; meta = m; pathDir = d }
  const XetoEnv env
  const Str name
  const Uri uri
  const Dict meta
  const File pathDir
}

