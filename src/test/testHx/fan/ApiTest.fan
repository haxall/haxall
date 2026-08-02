//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Jun 2021  Brian Frank  Creation
//  18 Feb 2025  Brian Frank  Split apart for 3 vs 5
//

using concurrent
using inet
using util
using web
using xeto
using haystack
using folio
using auth
using axon
using hx

**
** ApiTest base class
**
abstract class ApiTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Dialect Hooks
//////////////////////////////////////////////////////////////////////////

  ** Protocol version under test
  abstract ApiVersion version()

  ** Call an op with named args and return the decoded result.  Version 4
  ** encodes the args as a request grid and decodes a response grid;
  ** version 5 encodes a JSON dict and decodes clean JSON.  Tests which
  ** behave identically in both dialects are written against this hook.
  abstract Obj? callOp(Client c, Str op, Str:Obj args)

  ** Set the Xeto-Version header for this dialect.  Version 4 is the
  ** assumed default so it sends no header, which also keeps the legacy
  ** no-header path under test.
  Void setVersionHeader(WebClient wc)
  {
    if (version !== ApiVersion.def) wc.reqHeaders["Xeto-Version"] = version.token
  }

  Uri? uri

  Client? a  // alice (op)
  Client? b  // bob (admin)
  Client? c  // charlie (su)

  Dict? siteA
  Dict? siteB
  Dict? siteC
  Dict? eqA1

//////////////////////////////////////////////////////////////////////////
// Tops
//////////////////////////////////////////////////////////////////////////

  Void init()
  {
    initData
    initSettings
    initClients
  }

  ** Run every test which behaves identically in both dialects.  These are
  ** either fully transport neutral (auth, the opWeb funcs, the ApiErr JSON
  ** envelope) or are written against the callOp hooks so that the
  ** same assertions run under each dialect's encoding.
  virtual Void doCommon()
  {
    doAuth
    doOpWebFuncs
    doErrJson
    doAbout
    doCommit
  }

  ** Auth failures and the scram handshake are independent of the op
  ** encoding, so they run once per dialect against the same assertions
  Void doAuth()
  {
    verifyAuthErrJson
    verifyAuthBadHeaderJson
    verifyAuthChallengeNotJson
  }

  Void cleanup()
  {
    a.close
    b.close
    c.close
    verifyErrMsg(IOErr#, "Bad HTTP response 403 Invalid or expired authToken") { c.about }
  }

//////////////////////////////////////////////////////////////////////////
// Init Data
//////////////////////////////////////////////////////////////////////////

  private Void initData()
  {
    if (sys.info.type.isSkySpark) addLib("hx.his")
    addLib("hx.point")

    try { sys.libs.add("hx.http") } catch (Err e) {}
    this.uri = sys.http.siteUri + `/api/${proj.name}/`

    // setup user accounts
    addUser("alice",   "a-secret", ["userRole":"op"])
    addUser("bob",     "b-secret", ["userRole":"admin"])
    addUser("charlie", "c-secret", ["userRole":"su"])

    // setup some site records
    siteA = addRec(["dis":"A", "site":m, "geoCity":"Richmond", "area":n(30_000)])
    siteB = addRec(["dis":"B", "site":m, "geoCity":"Norfolk",  "area":n(20_000)])
    siteC = addRec(["dis":"C", "site":m, "geoCity":"Roanoke",  "area":n(10_000)])

    // equip
    eqA1 = addRec(["dis":"A1", "equip":m, "siteRef":siteA.id])

    // points
    ptX := addRec(["dis":"A1X", "point":m, "siteRef":siteA.id, "equipRef":eqA1.id])
    ptY := addRec(["dis":"A1Y", "point":m, "siteRef":siteA.id, "equipRef":eqA1.id])
  }

//////////////////////////////////////////////////////////////////////////
// Init Settings
//////////////////////////////////////////////////////////////////////////

  Void initSettings()
  {
    if (sys.info.type.isSkySpark) return

    ext := proj.ext("hx.http")
    rec := ext.settings
    host := IpAddr.local.hostname
    port := rec.has("httpPort") ? ((Number)rec->httpPort).toInt : 8080
    defSiteUri := `http://${host}:${port}/`

    // default on initialization
    verifySiteUri(defSiteUri)

    // set siteUri in settings
    ext.settingsUpdate(Diff(ext.settings, ["siteUri":`http://test-it/`]))
    verifySiteUri(`http://test-it/`)

    // clear siteUri in settings, fallback to default
    ext.settingsUpdate(Diff(ext.settings, ["siteUri":None.val]))
    verifySiteUri(defSiteUri)
  }

  Void verifySiteUri(Uri expected)
  {
    verifyEq(proj.sys.http.siteUri, expected)
    verifyEq(eval("httpSiteUri()"), expected)
  }

//////////////////////////////////////////////////////////////////////////
// Init Clients (test auth)
//////////////////////////////////////////////////////////////////////////

  Void initClients()
  {
    a = authOk("alice",   "a-secret")
    b = authOk("bob",     "b-secret")
    c = authOk("charlie", "c-secret")

    authFail("wrong", "wrong")
    authFail("alice", "wrong")
  }

  private Client authOk(Str user, Str pass)
  {
    c := auth(user, pass)
    verifyEq(c.auth->user, user)
    return c
  }

  private Void authFail(Str user, Str pass)
  {
    verifyErr(AuthErr#) { auth(user, pass) }
  }

  ** A terminal auth failure must report a sys.api::AuthErr JSON body.
  ** The status code must NOT be 401: AuthClientContext.openStd loops
  ** while the server answers 401, so a 401 here would be read as another
  ** handshake round and fail with "Loop count exceeded" instead of a
  ** clean AuthErr.  The 403 is what terminates that loop.
  Void verifyAuthErrJson()
  {
    // drive the scram handshake far enough to get the terminal rejection
    wc := WebClient(uri + `about`)
    wc.reqHeaders["Authorization"] = "bearer authToken=bogus-token-value"
    wc.writeReq
    wc.readRes

    verifyEq(wc.resCode, 403)
    verifyNotEq(wc.resCode, 401)
    verifyEq(wc.resHeaders["Content-Type"], "application/json")

    json := (Str:Obj?)JsonInStream(wc.resStr.in).readJson
    wc.close
    verifyEq(json["spec"], "sys.api::AuthErr")
    verifyEq(json["status"], 403)
    verifyEq(json["dis"], "Invalid or expired authToken")

    // the security headers still ride along with the JSON body
    verifyEq(wc.resHeaders["Cache-Control"], "no-cache, no-store, private")
    verifyEq(wc.resHeaders["X-Frame-Options"], "SAMEORIGIN")
  }

  ** A malformed Authorization header is a 400 AuthErr, distinct from the
  ** 401 challenge which is a handshake step and carries no body
  Void verifyAuthBadHeaderJson()
  {
    wc := WebClient(uri + `about`)
    wc.reqHeaders["Authorization"] = "this-is-not-a-valid-auth-msg"
    wc.writeReq
    wc.readRes

    verifyEq(wc.resCode, 400)
    verifyEq(wc.resHeaders["Content-Type"], "application/json")

    str := wc.resStr
    json := (Str:Obj?)JsonInStream(str.in).readJson
    wc.close
    verifyEq(json["spec"], "sys.api::AuthErr")
    verifyEq(json["status"], 400)
    verifyEq(json["dis"], "Missing username or handshakeToken in Authorization header")
  }

  ** The 401 challenge is a handshake step, not an error: it must carry
  ** the WWW-Authenticate header and an empty body so that
  ** AuthClientContext.openStd can continue the scram exchange
  Void verifyAuthChallengeNotJson()
  {
    wc := WebClient(uri + `about`)
    wc.reqHeaders["Authorization"] = "hello username=" + "alice".toBuf.toBase64Uri
    wc.writeReq
    wc.readRes

    verifyEq(wc.resCode, 401)
    verifyNotNull(wc.resHeaders["WWW-Authenticate"])
    verifyNotEq(wc.resHeaders["Content-Type"], "application/json")
    verifyEq(wc.resStr, "")
    wc.close
  }

  private Client auth(Str user, Str pass)
  {
    Client.open(uri, user, pass)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Verify the GET/POST contract for an op.  An op marked <noSideEffects>
  ** must accept GET with its args as query params; every other op must
  ** reject GET with a 405 MethodNotAllowedErr and accept only POST.  This
  ** is enforced by ApiDispatch.checkMethod so it holds in both dialects.
  Void verifyOpMethods(Str op, Bool noSideEffects, Str query := "")
  {
    if (noSideEffects)
      verifyGetAllowed(op, query)
    else
      verifyGetNotAllowed(op, query)
  }

  ** An op with <noSideEffects> answers GET with its args as query params
  Void verifyGetAllowed(Str op, Str query := "")
  {
    wc := c.toWebClient(query.isEmpty ? op.toUri : "$op?$query".toUri)
    setVersionHeader(wc)
    wc.writeReq
    wc.readRes
    verifyEq(wc.resCode, 200)
    try { wc.resIn.readAllBuf } catch (Err e) {}
    wc.close
  }

  ** An op without <noSideEffects> rejects GET with 405 and a
  ** sys.api::MethodNotAllowedErr body listing POST as the allowed method
  Void verifyGetNotAllowed(Str op, Str query := "")
  {
    wc := c.toWebClient(query.isEmpty ? op.toUri : "$op?$query".toUri)
    setVersionHeader(wc)
    wc.writeReq
    wc.readRes
    verifyEq(wc.resCode, 405)
    verifyEq(wc.resPhrase.startsWith("GET not allowed for op"), true)

    json := (Str:Obj?)JsonInStream(wc.resStr.in).readJson
    wc.close
    verifyEq(json["spec"], "sys.api::MethodNotAllowedErr")
    verifyEq(json["status"], 405)
    verifyEq(json["allow"], Obj?["POST"])
  }

  Void verifyPermissionErr(|This| f)
  {
    try
    {
      f(this)
      fail
    }
    catch (CallErr e)
    {
      verify(e.msg.startsWith("haystack::PermissionErr:"))
    }
  }

//////////////////////////////////////////////////////////////////////////

  ** Failures in the HTTP processing itself - as opposed to a failure raised
  ** by the op function - return a real status code with a `sys.api::ApiErr`
  ** subtype encoded as clean JSON in both dialects.  The spec tag is the
  ** programmatic contract; the status code is advisory.
  Void doErrJson()
  {
    // unknown proj
    err := verifyErrJson(`/api/badProjName/about`, 404)
    verifyEq(err["spec"], "sys.api::UnknownProjErr")
    verifyEq(err["projName"], "badProjName")

    // unknown op
    err = verifyErrJson(`/api/$proj.name/badOpName`, 404)
    verifyEq(err["spec"], "sys.api::UnknownFuncErr")
    verifyEq(err["funcName"], "badOpName")

    // GET on an op with side effects
    err = verifyErrJson(`/api/$proj.name/eval?expr=now()`, 405)
    verifyEq(err["spec"], "sys.api::MethodNotAllowedErr")
    verifyEq(err["allow"], Obj?["POST"])

    // bad Xeto-Version header; allowed versions are ApiVersion scalar
    // tokens so the format stays open to non-integer versions later
    err = verifyErrJson(`/api/$proj.name/about`, 400, "7")
    verifyEq(err["spec"], "sys.api::UnsupportedVersionErr")
    verifyEq(err["allow"], Obj?["4", "5"])

    // non-numeric version header is rejected the same way
    err = verifyErrJson(`/api/$proj.name/about`, 400, "bogus")
    verifyEq(err["spec"], "sys.api::UnsupportedVersionErr")
  }

  ** Request uri and verify a JSON ApiErr body with the given status code
  Str:Obj? verifyErrJson(Uri uri, Int code, Str? version := null)
  {
    wc := c.toWebClient(uri)
    if (version != null) wc.reqHeaders["Xeto-Version"] = version
    wc.writeReq
    wc.readRes
    verifyEq(wc.resCode, code)
    verifyEq(wc.resHeaders["Content-Type"], "application/json")
    json := (Str:Obj?)JsonInStream(wc.resStr.in).readJson
    wc.close

    // every err carries the advisory status as a JSON integer plus a
    // human readable dis matching the status phrase
    verifyEq(json["status"], code)
    verifyEq(json["dis"], wc.resPhrase)
    verify((json["spec"] as Str).startsWith("sys.api::"))
    return json
  }

//////////////////////////////////////////////////////////////////////////
// opWeb Funcs
//////////////////////////////////////////////////////////////////////////

  ** The "ext" and "file" ops are serviced by `opWeb` marked funcs which
  ** read the web request and write the response themselves.  These tests
  ** must pass in both dialects: the v4 wire contract used here, and the
  ** v5 contract selected by the Xeto-Version header.  Since an opWeb func
  ** performs no request decoding or response encoding, its behavior is
  ** identical in both - which is exactly why they migrate first.
  Void doOpWebFuncs()
  {
    verifyOpWebSpecs
    verifyFileOp
    verifyExtOp
  }

// About
//////////////////////////////////////////////////////////////////////////

  Void doAbout()
  {
    verifyAbout(a)
    verifyAbout(b)
    verifyAbout(c)
  }

  private Void verifyAbout(Client c)
  {
    about := c.about
    verifyEq(about->haystackVersion,      proj.defs.lib("ph").version.toStr)
    verifyEq(about->whoami,               c.auth->user)
    verifyEq(about->tz,                   TimeZone.cur.name)
    verifyEq(about->productName,          sys.info.productName)
    verifyEq(about->productVersion,       sys.info.productVersion)
    verifyEq(about->vendorName,           sys.info.vendorName)
    verifyEq(about->vendorUri,            sys.info.vendorUri)
    verifyEq(about->serverName,           Env.cur.host)
    verifyEq(about->serverTime->date,     Date.today)
    verifyEq(about->serverBootTime->date, Date.today)
  }

//////////////////////////////////////////////////////////////////////////
// Commit
//////////////////////////////////////////////////////////////////////////

  Void doCommit()
  {
    verifyPermissionErr { this.verifyCommit(this.a) }
    verifyCommit(b)
    verifyCommit(c)
  }

  private Void verifyCommit(Client c)
  {
    // add
    db := proj.db
    verifyEq(db.readCount(Filter("foo")), 0)
    g := c.callGrid("commit", Etc.makeMapGrid(["commit":"add"], ["dis":"Commit Test", "foo":m]))
    r := g.first as Dict
    verifyEq(db.readCount(Filter("foo")), 1)
    verifyDictEq(db.read(Filter("foo")), r)

    // update
    g = c.callGrid("commit", Etc.makeMapGrid(["commit":"update"], ["id":r.id, "mod":r->mod, "bar":"baz"]))
    r = readById(r.id)
    verifyEq(r["bar"], "baz")
    verifyDictEq(r, g.first)

    // update transient
    g = c.callGrid("commit", Etc.makeMapGrid(["commit":"update", "transient":m], ["id":r.id, "mod":r->mod, "curVal":n(123)]))
    r = readById(r.id)
    verifyEq(r["curVal"], n(123))

    // update force
    g = c.callGrid("commit", Etc.makeMapGrid(["commit":"update", "force":m], ["id":r.id, "mod":DateTime.nowUtc, "forceIt":"forced!"]))
    r = readById(r.id)
    verifyEq(r["forceIt"], "forced!")

    // remove
    g = c.callGrid("commit", Etc.makeMapGrid(["commit":"remove"], ["id":r.id, "mod":r->mod]))
    verifyEq(db.readById(r.id, false), null)
  }


  ** Both funcs resolve to hx.api, carry opWeb, and take no parameters
  private Void verifyOpWebSpecs()
  {
    cx := makeContext(null)
    ["ext", "file"].each |n|
    {
      f := cx.ns.funcs.getAll(n).find |x| { x.meta.has("opWeb") }
      verifyNotNull(f, n)
      verifyEq(f.qname, "hx.api::Funcs.${n}")
      verifyEq(f.func.params.size, 0)
      verifyEq(f.meta.has("op"), true)
    }
  }

  ** GET downloads via FileWeblet; POST/PUT routes to the ext upload handler
  private Void verifyFileOp()
  {
    Actor.locals[ActorContext.actorLocalsKey] = makeContext(null)
    proj.sys.file.resolve(`/io/opweb.txt`).out.print("hello opWeb").close

    // GET downloads the file
    verifyEq(c.toWebClient(`file/io/opweb.txt`).getStr, "hello opWeb")

    // GET sets the identity headers which FileWeblet provides
    wc := c.toWebClient(`file/io/opweb.txt`)
    wc.writeReq; wc.readRes
    verifyEq(wc.resCode, 200)
    verifyNotNull(wc.resHeaders["ETag"])
    verifyNotNull(wc.resHeaders["Last-Modified"])
    etag := wc.resHeaders["ETag"]
    wc.resIn.readAllBuf; wc.close

    // conditional GET returns 304 Not Modified
    wc = c.toWebClient(`file/io/opweb.txt`)
    wc.reqHeaders["If-None-Match"] = etag
    wc.writeReq; wc.readRes
    verifyEq(wc.resCode, 304)
    wc.close

    // unknown file is 404
    verifyEq(webCode(`file/io/nope-not-here.txt`), 404)

    // a directory path is 404 (download requires a file)
    verifyEq(webCode(`file/io/`), 404)

    // methods other than GET/POST/PUT are 501 not implemented
    verifyEq(webCode(`file/io/opweb.txt`, "DELETE"), 501)

    // upload is unsupported by the haxall file ext: FileExt does not
    // override uploadHandler so the base UploadHandler stub returns 404.
    // SkySpark's XFileExt and xb's XbFileExt do support it.
    verifyEq(webPut(`file/io/other.txt`, "x"), 404)
  }

  ** Re-dispatches to another ext's WebMod by rewriting req.mod/modBase
  private Void verifyExtOp()
  {
    // routes to hxd::HxdUserWeb which serves login.css
    wc := c.toWebClient(`ext/user/login.css`)
    wc.writeReq; wc.readRes
    verifyEq(wc.resCode, 200)
    verifyEq(wc.resHeaders["Content-Type"].startsWith("text/css"), true)
    verify(wc.resIn.readAllStr.size > 0)
    wc.close

    // the delegate sees its own modRel: HxdUserWeb 404s an unknown route
    verifyEq(webCode(`ext/user/notARoute`), 404)

    // unknown ext route is 404
    verifyEq(webCode(`ext/notAnExtRoute/`), 404)

    // empty route name is 404
    verifyEq(webCode(`ext/`), 404)
  }

  ** PUT the body to the uri and return the response status code
  Int webPut(Uri uri, Str body)
  {
    wc := c.toWebClient(uri)
    wc.reqMethod = "PUT"
    wc.reqHeaders["Content-Type"] = "text/plain"
    wc.reqHeaders["Content-Length"] = body.size.toStr
    wc.writeReq
    wc.reqOut.print(body).close
    wc.readRes
    code := wc.resCode
    try { wc.resIn.readAllBuf } catch (Err e) {}
    wc.close
    return code
  }

  ** Request the uri and return the response status code
  Int webCode(Uri uri, Str method := "GET")
  {
    wc := c.toWebClient(uri)
    wc.reqMethod = method
    wc.writeReq
    wc.readRes
    code := wc.resCode
    try { wc.resIn.readAllBuf } catch (Err e) {}
    wc.close
    return code
  }

}

