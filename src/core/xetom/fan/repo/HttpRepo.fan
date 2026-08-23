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

//////////////////////////////////////////////////////////////////////////
// RemoteRepo
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
    libs := toLibVersions(res["libs"])
    return MRemoteRepoSearchRes
    {
      it.libs   = libs
      it.total  = toInt(res["total"])  ?: libs.size
      it.limit  = toInt(res["limit"])  ?: req.limit
      it.offset = toInt(res["offset"]) ?: 0
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

  ** Map JSON list of RepoLib dicts to LibVersions
  private LibVersion[] toLibVersions(Obj? json)
  {
    list := json as List
    if (list == null) return LibVersion#.emptyList
    return list.map |x->LibVersion| { toLibVersion(x) }
  }

  ** Map JSON RepoLib dict to LibVersion
  private LibVersion toLibVersion(Str:Obj? json)
  {
    RemoteLibVersion.makeDict(Etc.dictFromMap(json))
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
  ** JSON response
  private Obj? callPost(Str op, File file)
  {
    c := toWebClient(op, Str:Str[:])
    try
    {
      c.reqMethod = "POST"
      c.reqHeaders["Content-Type"] = "application/xetolib"
      c.reqHeaders["Content-Length"] = file.size.toStr
      c.writeReq
      file.in.pipe(c.reqOut, file.size)
      c.reqOut.close
      c.readRes
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

  ** Prepare web client for an op GET request
  private WebClient toWebClient(Str op, Str:Str args)
  {
    c := WebClient(uri.plusSlash.plusName(op).plusQuery(args))
    c.reqHeaders["Xeto-Version"] = ApiVersion.cur.token
    token := authToken(false)
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
    throw IOErr("$op failed: $dis [$uri]")
  }
}

