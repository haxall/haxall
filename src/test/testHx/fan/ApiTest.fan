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
    if (sys.info.rt.isSkySpark) addLib("hx.his")
    addLib("hx.point")

    try { sys.libs.add("hx.http") } catch (Err e) {}
    this.uri = sys.http.siteUri + `/api/sys/`

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
    if (sys.info.rt.isSkySpark) return

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
    ext.settingsUpdate(Diff(ext.settings, ["siteUri":Remove.val]))
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

  private Client auth(Str user, Str pass)
  {
echo(">>>>> open $uri")
    return Client.open(uri, user, pass)
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

