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

  ** Call a grid based op such as commit or hisWrite with its request
  ** grid.  Version 4 posts the grid as the body; version 5 passes it as
  ** the named "req" arg encoded per the Jeto grid rules.  The payloads
  ** and assertions are shared - only the encoding differs.
  abstract Grid callGridOp(Client c, Str op, Grid req)

  ** Poll a watch.  This is the one op whose wire shape differs between
  ** dialects: version 4 carries watchId/refresh in the request grid
  ** meta while version 5 models them as named args.
  abstract Grid callWatchPoll(Client c, Str watchId, Bool refresh := false)

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
  Dict? ptX
  Dict? ptY
  Dict? ptW

//////////////////////////////////////////////////////////////////////////
// Tops
//////////////////////////////////////////////////////////////////////////

  Void init()
  {
    traceInit
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
    doNav
    doPointWrite
    doWatches
    doHis
  }

  ** Auth failures and the scram handshake are independent of the op
  ** encoding, so they run once per dialect against the same assertions
  Void doAuth()
  {
    traceSection("doAuth")
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
    traceReport
  }

//////////////////////////////////////////////////////////////////////////
// Init Data
//////////////////////////////////////////////////////////////////////////

  private Void initData()
  {
    if (sys.info.type.isSkySpark) addLib("hx.his")
    addLib("hx.point")

    addHttpExt
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
    ptX = addRec(["dis":"A1X", "point":m, "siteRef":siteA.id, "equipRef":eqA1.id])
    ptY = addRec(["dis":"A1Y", "point":m, "siteRef":siteA.id, "equipRef":eqA1.id])
    ptW = addRec(["dis":"A1W", "point":m, "writable":m, "kind":"Number", "siteRef":siteA.id, "equipRef":eqA1.id])
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
    port := rec.has("httpPort") ? ((Number)rec->httpPort).toInt : httpPort
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
    traceSection("initClients (auth handshake)")
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
    verifyErrVersionHeader(wc)

    resBody := wc.resStr
    wc.close
    trace(wc, null, resBody)
    json := (Str:Obj?)JsonInStream(resBody.in).readJson
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
    verifyErrVersionHeader(wc)

    str := wc.resStr
    json := (Str:Obj?)JsonInStream(str.in).readJson
    wc.close
    trace(wc, null, str)
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
    trace(wc, null, null)
  }

  private Client auth(Str user, Str pass)
  {
    Client.open(uri, user, pass, ["log": traceLog])
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Verify the GET/POST contract for an op.  An op marked <noSideEffects>
  ** must accept GET with its args as query params; every other op must
  ** reject GET with a 405 MethodNotAllowedErr and accept only POST.  Any
  ** method other than GET/POST is 501 for every op.  This is enforced by
  ** ApiDispatch.checkMethod so it holds in both dialects.
  Void verifyOpMethods(Str op, Bool noSideEffects, Str query := "")
  {
    if (noSideEffects)
      verifyGetAllowed(op, query)
    else
      verifyGetNotAllowed(op, query)
    verifyMethodNotImplemented(op)
  }

  ** Neither GET nor POST is a 501 NotImplementedErr regardless of
  ** whether the op declares <noSideEffects>
  Void verifyMethodNotImplemented(Str op, Str method := "DELETE")
  {
    wc := c.toWebClient(op.toUri)
    wc.reqMethod = method
    setVersionHeader(wc)
    wc.writeReq
    wc.readRes
    verifyEq(wc.resCode, 501)

    resBody := wc.resStr
    wc.close
    trace(wc, null, resBody)
    json := (Str:Obj?)JsonInStream(resBody.in).readJson
    verifyEq(json["spec"], "sys.api::NotImplementedErr")
    verifyEq(json["status"], 501)
  }

  ** An op with <noSideEffects> answers GET with its args as query params
  Void verifyGetAllowed(Str op, Str query := "")
  {
    wc := c.toWebClient(query.isEmpty ? op.toUri : "$op?$query".toUri)
    setVersionHeader(wc)
    wc.writeReq
    wc.readRes
    verifyEq(wc.resCode, 200)
    Str? resBody := null
    try { resBody = wc.resIn.readAllStr } catch (Err e) {}
    wc.close
    trace(wc, null, resBody)
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

    resBody := wc.resStr
    wc.close
    trace(wc, null, resBody)
    json := (Str:Obj?)JsonInStream(resBody.in).readJson
    verifyEq(json["spec"], "sys.api::MethodNotAllowedErr")
    verifyEq(json["status"], 405)
    verifyEq(json["allow"], Obj?["POST"])
  }

  ** Every error response reports the server's current version, no matter
  ** which version the request selected: many errors occur before version
  ** resolution, so echoing the negotiated version is not even well
  ** defined on the error path
  Void verifyErrVersionHeader(WebClient wc)
  {
    verifyEq(wc.resHeaders["Xeto-Version"], ApiVersion.cur.token)
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
      // v4 reports the err grid errType prefix; v5 the ApiErr spec
      verify(e.msg.startsWith("haystack::PermissionErr:") ||
             e.meta["spec"] == "sys.api::PermissionErr")
    }
  }

//////////////////////////////////////////////////////////////////////////

  ** Failures in the HTTP processing itself - as opposed to a failure raised
  ** by the op function - return a real status code with a `sys.api::ApiErr`
  ** subtype encoded as clean JSON in both dialects.  The spec tag is the
  ** programmatic contract; the status code is advisory.
  Void doErrJson()
  {
    traceSection("doErrJson")
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
    setVersionHeader(wc)
    if (version != null) wc.reqHeaders["Xeto-Version"] = version
    wc.writeReq
    wc.readRes
    verifyEq(wc.resCode, code)
    verifyEq(wc.resHeaders["Content-Type"], "application/json")
    verifyErrVersionHeader(wc)
    resBody := wc.resStr
    wc.close
    trace(wc, null, resBody)
    json := (Str:Obj?)JsonInStream(resBody.in).readJson

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
    traceSection("doOpWebFuncs")
    verifyOpWebSpecs
    verifyFileOp
    verifyExtOp
  }

// About
//////////////////////////////////////////////////////////////////////////

  Void doAbout()
  {
    traceSection("doAbout")
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
    traceSection("doCommit")
    verifyPermissionErr { this.verifyCommit(this.a) }
    verifyCommit(b)
    verifyCommit(c)
  }

  private Void verifyCommit(Client c)
  {
    // add
    db := proj.db
    verifyEq(db.readCount(Filter("foo")), 0)
    g := callGridOp(c, "commit", Etc.makeMapGrid(["commit":"add"], ["dis":"Commit Test", "foo":m]))
    r := g.first as Dict
    verifyEq(db.readCount(Filter("foo")), 1)
    verifyDictEq(db.read(Filter("foo")), r)

    // update
    g = callGridOp(c, "commit", Etc.makeMapGrid(["commit":"update"], ["id":r.id, "mod":r->mod, "bar":"baz"]))
    r = readById(r.id)
    verifyEq(r["bar"], "baz")
    verifyDictEq(r, g.first)

    // update transient
    g = callGridOp(c, "commit", Etc.makeMapGrid(["commit":"update", "transient":m], ["id":r.id, "mod":r->mod, "curVal":n(123)]))
    r = readById(r.id)
    verifyEq(r["curVal"], n(123))

    // update force
    g = callGridOp(c, "commit", Etc.makeMapGrid(["commit":"update", "force":m], ["id":r.id, "mod":DateTime.nowUtc, "forceIt":"forced!"]))
    r = readById(r.id)
    verifyEq(r["forceIt"], "forced!")

    // remove
    g = callGridOp(c, "commit", Etc.makeMapGrid(["commit":"remove"], ["id":r.id, "mod":r->mod]))
    verifyEq(db.readById(r.id, false), null)
  }


//////////////////////////////////////////////////////////////////////////
// Nav
//////////////////////////////////////////////////////////////////////////

  ** Nav keeps its grid contract: the root request is the empty grid and
  ** each level navigates by the navId of a returned row
  Void doNav()
  {
    traceSection("doNav")
    if (sys.info.type.isSkySpark) return

    g := callGridOp(c, "nav", Etc.makeMapGrid(null, Str:Obj[:]))
    verifyEq(g.size, 3)
    verifyEq(g[0].dis, "A")
    verifyEq(g[0].id, g[0]["navId"])

    g = callGridOp(c, "nav", Etc.makeMapGrid(null, Str:Obj["navId":g[0].id]))
    verifyEq(g.size, 1)
    verifyEq(g[0].dis, "A1")
    verifyEq(g[0].id, g[0]["navId"])

    g = callGridOp(c, "nav", Etc.makeMapGrid(null, Str:Obj["navId":g[0].id]))
    verifyEq(g.size, 3)
    verifyEq(g[0].dis, "A1W")
    verifyEq(g[0]["navId"], null)
  }

//////////////////////////////////////////////////////////////////////////
// Point Write
//////////////////////////////////////////////////////////////////////////

  ** pointWrite models its parameters: a v4 request carries them as a
  ** single row's columns, v5 as named args - the callOp hook encodes
  ** the same payload per dialect
  Void doPointWrite()
  {
    traceSection("doPointWrite")
    callOp(c, "pointWrite", ["id":ptW.id, "level":n(16), "val":n(160)])
    callOp(c, "pointWrite", ["id":ptW.id, "level":n(8), "val":n(80), "duration":n(1, "hr")])
    res := (Grid)callOp(c, "pointWrite", ["id":ptW.id])

    verifyEq(res.size, 17)
    verifyEq(res[7]->level, n(8))
    verifyEq(res[7]->val, n(80))
    verifyEq(res[7].has("expires"), true)

    verifyEq(res[15]->level, n(16))
    verifyEq(res[15]->val, n(160))

    // write requires admin, read does not
    verifyPermissionErr { this.callOp(this.a, "pointWrite", ["id":this.ptW.id, "level":n(16), "val":n(70)]) }
    verifyEq(((Grid)callOp(a, "pointWrite", ["id":ptW.id])).size, 17)
  }

//////////////////////////////////////////////////////////////////////////
// Watches
//////////////////////////////////////////////////////////////////////////

  ** watchSub/watchUnsub keep their grid contracts; watchPoll models its
  ** parameters, which a v4 request carries as the request grid meta
  Void doWatches()
  {
    traceSection("doWatches")
    // watchSub
    w := proj.watch
    verifyEq(w.isWatched(siteA.id), false)
    verifyEq(w.isWatched(eqA1.id), false)
    res := callGridOp(c, "watchSub", Etc.makeListGrid(["watchDis":"test", "lease":n(17, "min")], "id", null, [siteA.id, eqA1.id]))
    watchId := (Str)res.meta->watchId
    verifyEq(res.meta->lease, n(17, "min"))
    verifyEq(res.size, 2)
    verifyDictEq(res[0], siteA)
    verifyDictEq(res[1], eqA1)
    verifyEq(w.list.size, 1)
    verifyEq(w.isWatched(siteA.id), true)
    verifyEq(w.isWatched(eqA1.id), true)
    verifyEq(w.list.first.dis, "test")
    verifyEq(w.list.first.lease, 17min)
    callWatchPoll(c, watchId)

    // watchPoll reports the changed rec
    eqA1 = commit(eqA1, ["foo":n(123)])
    g := callWatchPoll(c, watchId)
    verifyEq(g.size, 1)
    verifyEq(g[0].id, eqA1.id)
    verifyEq(g[0]->foo, n(123))

    // refresh poll returns every watched entity
    g = callWatchPoll(c, watchId, true)
    verifyEq(g.size, 2)

    // watchUnsub one entity
    callGridOp(c, "watchUnsub", Etc.makeListGrid(["watchId":watchId], "id", null, [eqA1.id]))
    verifyEq(w.isWatched(siteA.id), true)
    verifyEq(w.isWatched(eqA1.id), false)

    // watchUnsub close; polling the closed watch errs in both dialects:
    // v4 as the legacy err grid, v5 as a 404 sys.api::UnknownEntityErr
    // so a client can distinguish an expired watch from a server fault
    callGridOp(c, "watchUnsub", Etc.makeEmptyGrid(["watchId":watchId, "close":m]))
    verifyEq(w.list.size, 0)
    verifyEq(w.isWatched(siteA.id), false)
    try { callWatchPoll(c, watchId); fail }
    catch (CallErr e)
      verify(e.msg.startsWith("hx::UnknownWatchErr") || e.meta["spec"] == "sys.api::UnknownEntityErr", e.msg)
  }

//////////////////////////////////////////////////////////////////////////
// His
//////////////////////////////////////////////////////////////////////////

  ** hisWrite and hisRead keep their grid contracts: single point rides
  ** the grid meta id, batch uses value columns with id column meta
  Void doHis()
  {
    traceSection("doHis")
    tz := TimeZone("New_York")
    today := DateTime.now.toTimeZone(tz).midnight
    yesterday := today.date.minus(1day).toDateTime(Time.defVal, tz)
    ptA := addRec(["dis":"His-A", "point":m, "his":m, "kind":"Number", "tz":tz.name])
    ptB := addRec(["dis":"His-B", "point":m, "his":m, "kind":"Number", "tz":tz.name])

    // hisWrite to ptA
    items := HisItem[,]
    items.add(HisItem(yesterday + 1hr, n(1)))
    items.add(HisItem(yesterday + 2hr, n(2)))
    items.add(HisItem(yesterday + 3hr, n(3)))
    items.add(HisItem(today + 1hr, n(10)))
    items.add(HisItem(today + 2hr, n(20)))
    items.add(HisItem(today + 3hr, n(30)))
    callGridOp(c, "hisWrite", Etc.makeDictsGrid(["id":ptA.id.noDis], items))

    // batch hisWrite to ptA, ptB
    gb := GridBuilder()
    ts := Date("2023-05-13").midnight
    gb.addCol("ts").addCol("v0", ["id":ptA.id.noDis]).addCol("v1", ["id":ptB.id.noDis])
    gb.addRow([ts + 0hr, n(100), n(200)])
    gb.addRow([ts + 1hr, null,   n(201)])
    gb.addRow([ts + 2hr, n(102), null])
    gb.addRow([ts + 3hr, n(103), n(203)])
    callGridOp(c, "hisWrite", gb.toGrid)

    // verify ptA got written
    proj.sync
    ptA = proj.readById(ptA.id)
    ptB = proj.readById(ptB.id)
    verifyEq(ptA["hisSize"], n(9))
    verifyEq(ptB["hisSize"], n(3))

    // hisRead from ptA (yesterday)
    res := callGridOp(c, "hisRead", Etc.makeMapGrid(null, ["id":ptA.id.noDis, "range":"yesterday"]))
    verifyEq(res.size, 3)
    verifyEq(res.meta->hisStart, yesterday)
    verifyEq(res.meta->hisEnd, today)
    verifyDictEq(res[0], items[0])
    verifyDictEq(res[1], items[1])
    verifyDictEq(res[2], items[2])

    // hisRead from ptA (today)
    res = callGridOp(c, "hisRead", Etc.makeMapGrid(null, ["id":ptA.id.noDis, "range":"today"]))
    verifyEq(res.size, 3)
    verifyDictEq(res[0], items[3])
    verifyDictEq(res[1], items[4])
    verifyDictEq(res[2], items[5])

    // hisRead from ptA (range)
    res = callGridOp(c, "hisRead", Etc.makeMapGrid(null, ["id":ptA.id.noDis, "range":items[4].ts.toStr]))
    verifyEq(res.size, 2)
    verifyDictEq(res[0], items[-2])
    verifyDictEq(res[1], items[-1])

    // batch hisRead
    gb = GridBuilder().setMeta(["range":"2023-05-13"]).addCol("id")
    gb.addRow1(ptA.id.noDis)
    gb.addRow1(ptB.id.noDis)
    res = callGridOp(c, "hisRead", gb.toGrid)
    verifyEq(res.size, 4)
    verifyEq(res.meta->hisStart, ts)
    verifyEq(res.meta->hisEnd, ts.plus(1day))
    verifyDictEq(res[0], ["ts":ts + 0hr, "v0":n(100), "v1":n(200)])
    verifyDictEq(res[1], ["ts":ts + 1hr, "v0":null,   "v1":n(201)])
    verifyDictEq(res[2], ["ts":ts + 2hr, "v0":n(102), "v1":null])
    verifyDictEq(res[3], ["ts":ts + 3hr, "v0":n(103), "v1":n(203)])

    // batch hisRead with explicit tz minus 1hr; first row clipped
    gb = GridBuilder().setMeta(["range":"2023-05-13", "tz":"Chicago"]).addCol("id")
    tsM1 := ts.date.midnight(TimeZone("Chicago"))
    gb.addRow1(ptA.id.noDis)
    gb.addRow1(ptB.id.noDis)
    res = callGridOp(c, "hisRead", gb.toGrid)
    verifyEq(res.size, 3)
    verifyEq(res.meta->hisStart.toStr, tsM1.toStr)
    verifyEq(res.meta->hisEnd.toStr, tsM1.plus(1day).toStr)
    verifyEq(res[0]->ts->tz.toStr, "Chicago")
    verifyDictEq(res[0], ["ts":tsM1 + 0hr, "v0":null,   "v1":n(201)])
    verifyDictEq(res[1], ["ts":tsM1 + 1hr, "v0":n(102), "v1":null])
    verifyDictEq(res[2], ["ts":tsM1 + 2hr, "v0":n(103), "v1":n(203)])

    // hisRead with span using Chicago timezone, results in point's tz
    res = callGridOp(c, "hisRead", Etc.makeMapGrid(null, ["id":ptA.id.noDis, "range":tsM1.toStr + "," +  tsM1.plus(1day).toStr]))
    verifyEq(res.size, 2)
    verifyEq(res.meta->hisStart.toStr, tsM1.toTimeZone(tz).toStr)
    verifyEq(res.meta->hisEnd.toStr, tsM1.plus(1day).toTimeZone(tz).toStr)
    verifyEq(res[0]->ts->tz.toStr, "New_York")
    verifyDictEq(res[0], ["ts":ts + 2hr, "val":n(102)])
    verifyDictEq(res[1], ["ts":ts + 3hr, "val":n(103)])

    // hisWrite requires admin
    verifyPermissionErr { this.callGridOp(this.a, "hisWrite", Etc.makeDictsGrid(["id":ptA.id.noDis], items)) }
  }

  ** Both funcs resolve to hx.api, carry opWebReq, and take no parameters
  private Void verifyOpWebSpecs()
  {
    cx := makeContext(null)
    ["ext", "file"].each |n|
    {
      f := cx.ns.funcs.getAll(n).find |x| { x.meta.has("opWebReq") }
      verifyNotNull(f, n)
      verifyEq(f.qname, "hx.api::Funcs.${n}")
      verifyEq(f.func.params.size, 0)
      verifyEq(f.meta.has("op"), true)
    }

    // ext writes its own response, file returns its result
    verifyEq(cx.ns.funcs.get("ext").meta.has("opWebRes"), true)
    verifyEq(cx.ns.funcs.get("file").meta.has("opWebRes"), false)
    verifyEq(cx.ns.funcs.get("openapi").meta.has("opWebRes"), true)
  }

  ** GET downloads via FileWeblet; POST/PUT routes to the ext upload handler
  private Void verifyFileOp()
  {
    Actor.locals[ActorContext.actorLocalsKey] = makeContext(null)
    proj.sys.file.resolve(`/io/opweb.txt`).out.print("hello opWeb").close

    // GET downloads the file
    dl := c.toWebClient(`file/io/opweb.txt`)
    setVersionHeader(dl)
    verifyEq(dl.getStr, "hello opWeb")

    // GET sets the identity headers which FileWeblet provides
    wc := c.toWebClient(`file/io/opweb.txt`)
    setVersionHeader(wc)
    wc.writeReq; wc.readRes
    verifyEq(wc.resCode, 200)
    verifyNotNull(wc.resHeaders["ETag"])
    verifyNotNull(wc.resHeaders["Last-Modified"])
    etag := wc.resHeaders["ETag"]
    resBody := wc.resIn.readAllStr; wc.close
    trace(wc, null, resBody)

    // conditional GET returns 304 Not Modified
    wc = c.toWebClient(`file/io/opweb.txt`)
    setVersionHeader(wc)
    wc.reqHeaders["If-None-Match"] = etag
    wc.writeReq; wc.readRes
    verifyEq(wc.resCode, 304)
    wc.close
    trace(wc, null, null)

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
    setVersionHeader(wc)
    wc.writeReq; wc.readRes
    verifyEq(wc.resCode, 200)
    verifyEq(wc.resHeaders["Content-Type"].startsWith("text/css"), true)
    resBody := wc.resIn.readAllStr
    verify(resBody.size > 0)
    wc.close
    trace(wc, null, resBody)

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
    setVersionHeader(wc)
    wc.reqMethod = "PUT"
    wc.reqHeaders["Content-Type"] = "text/plain"
    wc.reqHeaders["Content-Length"] = body.size.toStr
    wc.writeReq
    wc.reqOut.print(body).close
    wc.readRes
    code := wc.resCode
    Str? resBody := null
    try { resBody = wc.resIn.readAllStr } catch (Err e) {}
    wc.close
    trace(wc, body, resBody)
    return code
  }

  ** Request the uri and return the response status code
  Int webCode(Uri uri, Str method := "GET")
  {
    wc := c.toWebClient(uri)
    setVersionHeader(wc)
    wc.reqMethod = method
    wc.writeReq
    wc.readRes
    code := wc.resCode
    Str? resBody := null
    try { resBody = wc.resIn.readAllStr } catch (Err e) {}
    wc.close
    trace(wc, null, resBody)
    return code
  }

//////////////////////////////////////////////////////////////////////////
// Trace
//////////////////////////////////////////////////////////////////////////

  ** Report of every raw request/response for review by eye.  Each chunk
  ** prints to stdout as it happens - so redirecting the test run captures
  ** the whole report - and accumulates for the report file written in
  ** cleanup.  Sites which exchange via WebClient call `trace` with the
  ** payloads in hand; haystack::Client and the auth handshake are
  ** captured through the client debug log.
  private StrBuf traceBuf := StrBuf()

  ** Hook to turn the trace report on/off
  const Bool traceOn := true

  ** Log passed to haystack::Client to capture its raw wire debug
  private const Log traceLog := ApiTraceLog(this)

  private Str? tracePendingReq

  ** Enable capture of the haystack::Client wire debug
  Void traceInit()
  {
    if (traceOn) traceLog.level = LogLevel.debug
  }

  ** Trace an exchange.  Call after readRes with the body payloads in
  ** hand since the req/res streams can be read only once.
  Void trace(WebClient wc, Str? reqBody, Str? resBody)
  {
    if (!traceOn) return
    traceHeader(traceOp(wc.reqUri), wc.reqHeaders["Content-Type"], wc.resHeaders["Content-Type"], version)
    s := StrBuf()
    s.add("$wc.reqMethod $wc.reqUri.relToAuth\n")
    wc.reqHeaders.each |v, n| { s.add("$n: $v\n") }
    traceBody(s, reqBody)
    s.add("\n")
    s.add("$wc.resCode $wc.resPhrase\n")
    wc.resHeaders.each |v, n| { s.add("$n: $v\n") }
    traceBody(s, resBody)
    s.add("\n")
    traceAdd(s.toStr)
  }

  ** haystack::Client logs its raw request and response as a pair of
  ** debug messages; join them under the standard exchange banner.  The
  ** client sends no Xeto-Version header, so its exchanges are the
  ** default v4 wire no matter which suite runs them - the banner
  ** reports that wire version, not the suite's.
  internal Void traceClientMsg(Str msg)
  {
    if (msg.startsWith(">")) { tracePendingReq = msg; return }
    if (!msg.startsWith("<") || tracePendingReq == null) return
    req := tracePendingReq
    tracePendingReq = null
    traceHeader(traceOp(traceClientUri(req)), traceClientHeader(req, "Content-Type"), traceClientHeader(msg, "Content-Type"), ApiVersion.def, "Client")
    traceAdd(req.trimEnd + "\n\n" + msg.trimEnd + "\n\n")
  }

  ** Banner for one exchange: "### <op> <req-type> <res-type> <ver>"
  private Void traceHeader(Str op, Str? reqType, Str? resType, ApiVersion ver, Str suffix := "")
  {
    line := "##################################################################\n"
    header := "### $op " + (reqType ?: "-") + " " + (resType ?: "-") + " v$ver.token $suffix"
    traceAdd(line + header.trimEnd + "\n" + line + "\n")
  }

  ** Mark a section of the trace report for the exchanges which follow;
  ** each test phase method calls this with its own name
  Void traceSection(Str title)
  {
    if (!traceOn) return
    line := "//////////////////////////////////////////////////////////////////////////\n"
    traceAdd("$line// $title\n$line\n")
  }

  ** Write the trace report file and echo its location
  Void traceReport()
  {
    if (!traceOn) return
    file := Env.cur.tempDir + `api-trace-v${version.token}.txt`
    file.out.print(traceBuf.toStr).close
    echo("   API trace report [$file.osPath]")
  }

  ** Every trace chunk prints to stdout as it happens and accumulates
  ** for the report file
  private Void traceAdd(Str chunk)
  {
    traceBuf.add(chunk)
    Env.cur.out.print(chunk).flush
  }

  private Void traceBody(StrBuf s, Str? body)
  {
    if (body == null || body.isEmpty) return
    s.add("\n").add(body.trimEnd).add("\n")
  }

  ** Op name for the trace header: the path after /api/{proj}/
  private static Str traceOp(Uri uri)
  {
    uri.path.getSafe(2) ?: uri.toStr
  }

  ** The second line of a client debug message is "METHOD uri"
  private static Uri traceClientUri(Str req)
  {
    line := req.splitLines.getSafe(1) ?: ""
    return (line.split(' ').getSafe(1) ?: "").toUri
  }

  ** Pull a header value out of a client debug message or "-" if missing
  private static Str traceClientHeader(Str msg, Str name)
  {
    line := msg.splitLines.find |x| { x.startsWith("$name:") }
    return line == null ? "-" : line[name.size+1..-1].trim
  }

}

**************************************************************************
** ApiTraceLog
**************************************************************************

** Routes the haystack::Client wire debug to its test's trace report.
** Overriding `log` keeps the records out of the standard log handlers
** so they never pollute the console output; unregistered so the level
** bump to debug is invisible to everything else.  The test is held via
** Unsafe since a log must be const; the client logs synchronously on
** the test's own thread so the hand-off is safe and the report stays
** in exchange order.
internal const class ApiTraceLog : Log
{
  new make(ApiTest test) : super("apiTrace", false) { this.testRef = Unsafe(test) }
  override Void log(LogRec rec) { ((ApiTest)testRef.val).traceClientMsg(rec.msg) }
  private const Unsafe testRef
}

