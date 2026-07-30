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

    verifyAuthErrJson
    verifyAuthBadHeaderJson
    verifyAuthChallengeNotJson
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

}

