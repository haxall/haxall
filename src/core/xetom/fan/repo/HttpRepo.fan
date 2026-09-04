//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2026  Brian Frank  Creation
//

using util
using web
using xeto
using haystack

**
** HttpRepo is the standard client for any server which publishes the
** "sys.repo" HTTP API.  The repo uri is the op base uri: each op is
** invoked as a GET of "{uri}{op}?{args}" with version 5 JSON responses.
** For a Haxall server the base uri is "https://host/api/{proj}/".
**
const class HttpRepo : MRemoteRepo
{
  new make(RemoteRepoInit init) : super(init) {}

  ** Open a session which authenticates each request with the configured
  ** bearer token, or anonymously when none is configured
  override RemoteRepoSession open() { HttpRepoSession(this, null) }

  ** Open a session which authenticates each request with the caller
  ** owned `haystack::Client` session, such as one opened with scram
  ** credentials or OAuth
  RemoteRepoSession openClient(Client client) { HttpRepoSession(this, client) }
}

**************************************************************************
** HttpRepoSession
**************************************************************************

**
** HttpRepoSession is a connected session to an HttpRepo.  Requests
** authenticate through the caller owned `haystack::Client` when given,
** otherwise each request resolves the repo's configured bearer token.
**
internal class HttpRepoSession : MRemoteRepoSession
{
  new make(HttpRepo repo, Client? client) : super(repo) { this.client = client }

  ** Caller owned client session or null to use the configured token
  private Client? client

//////////////////////////////////////////////////////////////////////////
// Ops
//////////////////////////////////////////////////////////////////////////

  override Dict? ping(Bool checked := true)
  {
    try
    {
      return Etc.dictFromMap(call("repoPing"))
    }
    catch (Err e)
    {
      if (checked) throw e
      return null
    }
  }

  override RemoteRepoSearchRes search(RemoteRepoSearchReq req)
  {
    res := (Str:Obj?)call("repoSearch", ["query": req.query, "limit": req.limit.toStr])
    return MRemoteRepoSearchRes
    {
      it.libs  = toLibSummaries(res["libs"])
      it.more  = res["more"] != null
      it.total = toInt(res["total"])
    }
  }

  override LibVersion[] versions(Str name, Dict? opts := null)
  {
    args := ["lib": name]
    v := opts?.get("versions"); if (v != null) args["versions"] = v.toStr
    n := opts?.get("limit");    if (n != null) args["limit"] = n.toStr
    return toLibVersions(call("repoVersions", args))
  }

  override Buf fetch(Str name, Version version)
  {
    callBuf("repoFetch", ["lib": name, "version": version.toStr])
  }

  override LibVersion publish(File file)
  {
    toLibVersion(callPost("repoPublish", file))
  }

//////////////////////////////////////////////////////////////////////////
// Decoding
//////////////////////////////////////////////////////////////////////////

  ** Map JSON list of RepoLibVersion dicts to LibVersions
  private LibVersion[] toLibVersions(Obj? json)
  {
    list := json as List
    if (list == null) return LibVersion#.emptyList
    return list.map |x->LibVersion| { toLibVersion(x) }
  }

  ** Map JSON RepoLibVersion dict to LibVersion
  private LibVersion toLibVersion(Str:Obj? json)
  {
    RemoteLibVersion.makeDict(Etc.dictFromMap(json))
  }

  ** Map JSON list of RepoLibSummary dicts to summaries
  private RepoLibSummary[] toLibSummaries(Obj? json)
  {
    list := json as List
    if (list == null) return RepoLibSummary#.emptyList
    return list.map |Str:Obj? x->RepoLibSummary|
    {
      MRepoLibSummary
      {
        it.lib             = x["lib"]
        it.latestVersion   = Version.fromStr(x["latestVersion"].toStr)
        it.latestMaturity  = LibMaturity.fromStr(x["latestMaturity"]?.toStr ?: "stable")
        it.latestPublished = x["latestPublished"] == null ? null : DateTime.fromStr(x["latestPublished"].toStr)
        it.latestStable    = x["latestStable"] == null ? null : Version.fromStr(x["latestStable"].toStr)
        it.deprecated      = x["deprecated"]
        it.doc             = x["doc"]
      }
    }
  }

  ** Coerce JSON number to Int
  private static Int? toInt(Obj? v) { v as Int ?: (v as Float)?.toInt }

//////////////////////////////////////////////////////////////////////////
// Transport
//////////////////////////////////////////////////////////////////////////

  ** Invoke an op as a GET and decode the JSON response
  private Obj? call(Str op, Str:Str args := Str:Str[:])
  {
    c := toWebClient(op, args)
    try
    {
      c.writeReq
      c.readRes
      checkRes(c, op)
      return JsonInStream(c.resStr.in).readJson
    }
    finally c.close
  }

  ** Invoke an op as a POST of the file's raw bytes and decode the
  ** JSON response.  The Expect header lets the server fail-fast on
  ** auth or validation with the body never sent; a body the server
  ** never reads aborts the connection on some platforms.
  private Obj? callPost(Str op, File file)
  {
    c := toWebClient(op, Str:Str[:])
    try
    {
      c.reqMethod = "POST"
      c.reqHeaders["Content-Type"] = "application/xetolib"
      c.reqHeaders["Content-Length"] = file.size.toStr
      c.reqHeaders["Expect"] = "100-continue"
      c.writeReq
      c.readRes
      if (c.resCode == 100)
      {
        file.in.pipe(c.reqOut, file.size)
        c.reqOut.close
        c.readRes
      }
      checkRes(c, op)
      return JsonInStream(c.resStr.in).readJson
    }
    finally c.close
  }

  ** Invoke an op as a GET and read the binary response
  private Buf callBuf(Str op, Str:Str args)
  {
    c := toWebClient(op, args)
    try
    {
      c.writeReq
      c.readRes
      checkRes(c, op)
      return c.resIn.readAllBuf.toImmutable
    }
    finally c.close
  }

  ** Prepare web client for an op request.  Redirects are never followed:
  ** an auth challenge redirect to a login page must fail as an error,
  ** and following one would re-send the auth headers to whatever host
  ** the redirect names.
  private WebClient toWebClient(Str op, Str:Str args)
  {
    c := WebClient(mrepo.uri.plusSlash.plusName(op).plusQuery(args))
    c.followRedirects = false
    c.reqHeaders["Xeto-Version"] = ApiVersion.cur.token
    if (client != null) return client.auth.prepare(c)
    token := mrepo.authToken(false)
    if (token != null) c.reqHeaders["Authorization"] = "bearer authToken=$token"
    return c
  }

  ** Verify 200 response or raise error using the ApiErr response dis
  private Void checkRes(WebClient c, Str op)
  {
    if (c.resCode == 200) return
    dis := "HTTP error code: $c.resCode"
    try
    {
      json := JsonInStream(c.resStr.in).readJson as Str:Obj?
      if (json?.get("dis") != null) dis = json["dis"].toStr
    }
    catch (Err e) {}
    throw IOErr("$op failed: $dis [$mrepo.uri]")
  }
}
