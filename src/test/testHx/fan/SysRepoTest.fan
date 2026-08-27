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
using xetom
using xetoc
using haystack
using axon
using hx
using hxRepo

**
** SysRepoTest tests the sys.repo ops which serve a project's own libs
** as a remote repo.  Each op is verified from both sides: the Axon
** func surface on the server and the HttpRepo client over HTTP.
**
class SysRepoTest : HxTest
{
  RemoteRepo? repo             // HttpRepo client bound to this proj
  RemoteRepoSession? session   // one open session used across every do method
  Client? client               // authenticated haystack client

  @HxTestProj
  Void test()
  {
    init
    doPing
    doSearch
    doVersions
    doFetch
    doPublish
    doClientAuth
    session.close
    client.close
  }

//////////////////////////////////////////////////////////////////////////
// Pluggable RepoServer
//////////////////////////////////////////////////////////////////////////

  ** An enabled ext which implements the RepoServer mixin takes over
  ** servicing the ops from the default NamespaceRepoServer
  @HxTestProj
  Void testPlug()
  {
    addLib("sys.repo")

    // default resolution serves the namespace
    Dict d := eval("repoPing()")
    verifyEq(d["dis"], proj.dis)

    // enable hx.test whose ext implements RepoServer
    addExt("hx.test")
    d = eval("repoPing()")
    verifyEq(d["dis"], "hx.test")

    // other ops delegate through the plugged server
    Dict res := eval("""repoSearch("*")""")
    verify(((List)res["libs"]).size > 0)
    verifyEq(((List)eval("""repoVersions("sys")""")).size, 1)
  }

//////////////////////////////////////////////////////////////////////////
// Init
//////////////////////////////////////////////////////////////////////////

  Void init()
  {
    // serve this project as a repo
    addLib("sys.repo")
    addHttpExt
    uri := sys.http.siteUri + `api/${proj.name}/`

    // any authenticated user may use the repo ops; authenticate as an
    // ordinary op user and steal the session bearer token
    addUser("alice", "a-secret", ["userRole":"op"])
    this.client = Client.open(uri, "alice", "a-secret")
    header := (Str)((Str:Str)client.auth->headers).getChecked("Authorization")
    token := header[header.index("authToken=")+10..-1]

    // resolve HttpRepo client and configure its auth token; the one
    // session opened here services every op call in the test, proving
    // a session works across many calls from a single open
    env := (MEnv)proj.ns.env
    env.envVarSet("XETO_REPO_TEST", token)
    this.repo = MRemoteRepo.create(RemoteRepoInit(env, "test", uri, Etc.dict0, env.workDir))
    verifyEq(repo.typeof, HttpRepo#)
    this.session = repo.open
  }

//////////////////////////////////////////////////////////////////////////
// Ping
//////////////////////////////////////////////////////////////////////////

  Void doPing()
  {
    // axon
    Dict d := eval("repoPing()")
    verifyEq(d["dis"], proj.dis)
    verifyEq(d["spec"], Ref("sys.repo::RepoPing"))

    // http client
    verifyEq(session.ping["dis"], proj.dis)
  }

//////////////////////////////////////////////////////////////////////////
// Search
//////////////////////////////////////////////////////////////////////////

  Void doSearch()
  {
    // axon: wildcard matches every lib in the namespace
    Dict res := eval("""repoSearch("*")""")
    libs := (List)res["libs"]
    verifyEq(res["spec"], Ref("sys.repo::RepoSearch"))
    verifyEq(res["total"], libs.size)
    verifyEq(res["offset"], 0)
    verifyRepoLib(libs.find |Dict d->Bool| { d["lib"] == "sys" }, "sys")
    verifyRepoLib(libs.find |Dict d->Bool| { d["lib"] == "sys.repo" }, "sys.repo")

    // axon: substring match
    res = eval("""repoSearch("sys.repo")""")
    libs = (List)res["libs"]
    verifyEq(libs.size, 1)
    verifyRepoLib(libs.first, "sys.repo")

    // axon: paging: limit slices, total unchanged
    res = eval("""repoSearch("*", 2)""")
    verifyEq(((List)res["libs"]).size, 2)
    verifyEq(res["limit"], 2)

    // axon: paging: offset past the end is an empty page
    res = eval("""repoSearch("*", 100, 10000)""")
    verifyEq(((List)res["libs"]).size, 0)

    // axon: no matches
    res = eval("""repoSearch("no-match-xyz")""")
    verifyEq(res["total"], 0)
    verifyEq(((List)res["libs"]).size, 0)

    // http client: wildcard hydrates LibVersions with paging metadata
    sr := session.search(RemoteRepoSearchReq("*"))
    verify(sr.libs.size > 0)
    verifyEq(sr.total, sr.libs.size)
    verifyLibVersion(sr.libs.find |v| { v.name == "sys" }, "sys")
    verifyLibVersion(sr.libs.find |v| { v.name == "sys.repo" }, "sys.repo")

    // http client: no matches
    sr = session.search(RemoteRepoSearchReq("no-match-xyz"))
    verifyEq(sr.libs.size, 0)
    verifyEq(sr.total, 0)
  }

//////////////////////////////////////////////////////////////////////////
// Versions
//////////////////////////////////////////////////////////////////////////

  Void doVersions()
  {
    ver := proj.ns.lib("sys").version

    // axon: known lib reports its single local version
    List list := eval("""repoVersions("sys")""")
    verifyEq(list.size, 1)
    verifyRepoLib(list.first, "sys")

    // axon: constraint which matches
    list = eval("""repoVersions("sys", "${ver.segments.first}.x.x")""")
    verifyEq(list.size, 1)

    // axon: constraint which does not match
    list = eval("""repoVersions("sys", "0.0.1")""")
    verifyEq(list.size, 0)

    // axon: limit passed as Axon number
    list = eval("""repoVersions("sys", null, 1)""")
    verifyEq(list.size, 1)

    // axon: unknown lib is an empty list, never an error
    list = eval("""repoVersions("no-match-xyz")""")
    verifyEq(list.size, 0)

    // http client: hydrated LibVersions
    vers := session.versions("sys")
    verifyEq(vers.size, 1)
    verifyLibVersion(vers.first, "sys")

    // http client: defaulted latest/latestMatch/version route through versions
    verifyEq(session.latest("sys").version, ver)
    verifyEq(session.version("sys", ver).version, ver)
    verifyNull(session.version("sys", Version("0.0.1"), false))
    verifyEq(session.latestMatch(LibDepend("sys", LibDependVersions("${ver.segments.first}.x.x"))).version, ver)

    // http client: unknown lib is an empty list
    verifyEq(session.versions("no-match-xyz").size, 0)
  }

//////////////////////////////////////////////////////////////////////////
// Fetch
//////////////////////////////////////////////////////////////////////////

  Void doFetch()
  {
    ver := proj.ns.lib("sys").version

    // axon: fetch and reload to verify round trip through xetolib format
    File f := eval("""repoFetch("sys", "$ver")""")
    verifyEq(f.basename, "sys")
    verifyEq(f.ext, "xetolib")
    verifyFetchedZip(f.readAllBuf, `axon/sys.xetolib`, ver)

    // axon: unknown lib and unknown version raise typed errors
    verifyFetchErr("""repoFetch("no-match-xyz", "1.0.0")""", "sys.repo::UnknownLibErr")
    verifyFetchErr("""repoFetch("sys", "0.0.1")""", "sys.repo::UnknownLibVersionErr")

    // http client: fetch buf and reload
    verifyFetchedZip(session.fetch("sys", ver), `http/sys.xetolib`, ver)

    // http client: unknown lib and version report the server's ApiErr dis
    verifyErrMsg(IOErr#, "repoFetch failed: Unknown lib: no-match-xyz [$repo.uri]") { this.session.fetch("no-match-xyz", Version("1.0.0")) }
    verifyErrMsg(IOErr#, "repoFetch failed: Unknown lib version: sys-0.0.1 [$repo.uri]") { this.session.fetch("sys", Version("0.0.1")) }
  }

//////////////////////////////////////////////////////////////////////////
// Publish
//////////////////////////////////////////////////////////////////////////

  ** The default namespace repo is read-only so publish reports a 501,
  ** but the POST exercises the whole file param plumbing: the raw body
  ** is spooled to a temp file and passed as the func's File arg
  Void doPublish()
  {
    // post a real zip; any xetolib works since the server rejects
    zip := session.fetch("sys", proj.ns.lib("sys").version)
    json := postZip(zip, "5", 501)
    verifyEq(json["spec"], "sys.api::NotImplementedErr")

    // file typed params are a version 5 feature; v4 is the default
    json = postZip(zip, null, 400)
    verifyEq(json["spec"], "sys.api::InvalidArgsErr")

    // repoPublish has side effects so GET is a 405
    wc := client.toWebClient(`repoPublish`)
    wc.writeReq
    wc.readRes
    verifyEq(wc.resCode, 405)
    wc.close
  }

  ** POST raw zip bytes to repoPublish and decode the JSON error body
  private Str:Obj? postZip(Buf zip, Str? version, Int code)
  {
    wc := client.toWebClient(`repoPublish`)
    wc.reqMethod = "POST"
    if (version != null) wc.reqHeaders["Xeto-Version"] = version
    wc.reqHeaders["Content-Type"] = "application/xetolib"
    wc.reqHeaders["Content-Length"] = zip.size.toStr
    wc.writeReq
    wc.reqOut.writeBuf(zip).close
    wc.readRes
    verifyEq(wc.resCode, code)
    json := (Str:Obj?)JsonInStream(wc.resStr.in).readJson
    wc.close
    verifyEq(json["status"], code)
    return json
  }

  Void verifyFetchedZip(Buf buf, Uri tmpName, Version ver)
  {
    expectDigest := XetoCrypto.digest(buf)
    tmp := tempDir + tmpName
    tmp.out.writeBuf(buf).close
    v := FileLibVersion.loadZipFile(tmp)
    verifyEq(v.name, "sys")
    verifyEq(v.version, ver)
    verifyEq(v.digest, expectDigest)
    verifySame(v.digest, v.digest)  // lazily computed once, then interned
  }

  Void verifyFetchErr(Str axon, Str spec)
  {
    try { eval(axon); fail(axon) }
    catch (EvalErr e)
    {
      api := e.cause as ApiErr
      verifyNotNull(api, axon)
      verifyEq(api.spec, spec)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Client Auth
//////////////////////////////////////////////////////////////////////////

  ** End to end proof of caller owned sessions: a session opened from
  ** the scram authenticated haystack::Client services many calls from
  ** the one open; the repo itself pins no auth state of its own.
  Void doClientAuth()
  {
    env := (MEnv)proj.ns.env
    uri := repo.uri

    // no token configured and no client session: the server's auth
    // challenge fails the op before it is ever dispatched
    bare := HttpRepo(RemoteRepoInit(env, "noauth", uri, Etc.dict0, env.workDir)).open
    verifyErr(IOErr#) { bare.ping }
    bare.close

    // one session opened from the scram client services multiple calls
    s := ((HttpRepo)MRemoteRepo.create(RemoteRepoInit(env, "scram", uri, Etc.dict0, env.workDir))).openClient(client)
    try
    {
      ver := proj.ns.lib("sys").version
      verifyEq(s.ping["dis"], proj.dis)
      verify(s.search(RemoteRepoSearchReq("*")).libs.size > 0)
      verifyEq(s.versions("sys").first.version, ver)
      verifyFetchedZip(s.fetch("sys", ver), `scram/sys.xetolib`, ver)
      verifyEq(s.ping["dis"], proj.dis)  // session stays live after many calls
    }
    finally s.close
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void verifyRepoLib(Dict? d, Str lib)
  {
    verifyNotNull(d, lib)
    verifyEq(d["lib"], lib)
    verifyEq(d["version"], proj.ns.lib(lib).version)
    verifyEq(d["maturity"], Scalar("sys::LibMaturity", "stable"))
    verifyEq(d["availability"], Scalar("sys.repo::RepoLibAvailability", "available"))
    verifyEq(d["spec"], Ref("sys.repo::RepoLib"))
  }

  Void verifyLibVersion(LibVersion? v, Str lib)
  {
    verifyNotNull(v, lib)
    verifyEq(v.name, lib)
    verifyEq(v.version, proj.ns.lib(lib).version)
    verifyEq(v.maturity, LibMaturity.stable)
    verifyEq(((RemoteLibVersion)v).availability, RepoLibAvailability.available)
  }
}
