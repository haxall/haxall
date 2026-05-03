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

  ** Return if an env var name if auth token is configured for this repo
  override Str? authTokenEnvName()
  {
    key1 := toAuthTokenEnvKey(name)
    val1 := toAuthTokenEnvVal(key1)
    if (val1 != null) return key1

    key2 := toAuthTokenEnvKey(authTokenTypeName)
    val2 := toAuthTokenEnvVal(key2)
    if (val2 != null) return key2

    return null
  }

  ** Get configured auth token for this repo as environment variable:
  **   1. XETO_REPO_{name}: by repo name
  **   2. XETO_REPO_{type}: by repo type if not null
  **   3. Raise exception or null based on checked flag
  Str? authToken(Bool checked := true)
  {
    key1 := toAuthTokenEnvKey(name)
    val1 := toAuthTokenEnvVal(key1)
    if (val1 != null) return val1

    key2 := toAuthTokenEnvKey(authTokenTypeName)
    val2 := toAuthTokenEnvVal(key2)
    if (val2 != null) return val2

    if (!checked) return null
    what := key2 == null ? key1 : "$key1 or $key2"
    throw Err("Missing env var: $what")
  }

  ** Type name to use for a group of repos such as "github"
  virtual Str? authTokenTypeName() { null }

  ** Return env var name formatted as XETO_REPO_{x}
  static Str? toAuthTokenEnvKey(Str? x)
  {
    if (x == null) return x
    return "XETO_REPO_${x.upper}"
  }

  ** Return env var value for given name
  static Str? toAuthTokenEnvVal(Str? key)
  {
    if (key == null) return null
    return Env.cur.vars.get(key)
  }

}

**************************************************************************
** TempRemoteRepo
**************************************************************************

internal const class TempRemoteRepo : MRemoteRepo
{
  new make(RemoteRepoInit init) : super(init) { Err().trace }

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

