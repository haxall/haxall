//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Apr 16  Brian Frank  Creation
//

using concurrent
using web

**
** RoundtripTest
**
class RoundtripTest : Test
{
  static const LogLevel clientLevel := LogLevel.info
  static const LogLevel serverLevel := LogLevel.info

  Service? wisp
  Int port

  Void test()
  {
    openServer

    verifyAccount("sally")   // scram
    verifyAccount("holden")  // hmac
    verifyAccount("peter")   // plaintext
    verifyAccount("xavier")  // x-plaintext
    verifyAuthBearer
    verifyMultiChallenge
    verifyOauth2ParamDecode

    closeServer
  }

  Void verifyAccount(Str user)
  {
    verifyBad(user, "bad-one")
    verifyGood(user, "pass-$user")
  }

  Void verifyAuthBearer()
  {
    user := "auth-bearer-token"
    verifyGood(user, "tok-$user")
    verifyErr(IOErr#) {
      cx := openClient(user, "bad-$user")
      testBody := "test" + (0..100).random
      c := cx.prepare(WebClient(cx.uri+ `?${testBody}`))
      c.getStr
    }
  }

  Void verifyBad(Str user, Str pass)
  {
    verifyErr(AuthErr#)
    {
      openClient(user, pass)
    }
  }

  Void verifyGood(Str user, Str pass)
  {
    cx := openClient(user, pass)
    verify(cx.isAuthenticated)
    testBody := "test" + (0..100).random
    c := cx.prepare(WebClient(cx.uri+ `?${testBody}`))
    if (user.startsWith("b"))
      verifyEq(c.reqHeaders["Authorization"], "Basic " + "$user:$pass".toBuf.toBase64)
    else
      verifyEq(c.reqHeaders["Authorization"], "bearer authToken=tok-$user")
    verifyEq(c.getStr, testBody)
  }

  Void openServer()
  {
    wisp = Slot.findMethod("wisp::WispService.testSetup").call(TestMod())
    wisp.start
    wisp->waitUntilListening
    port = wisp->httpPort
  }

  Void closeServer()
  {
    wisp.stop
  }

  AuthClientContext openClient(Str user, Str pass)
  {
    AuthClientContext.open(`http://localhost:$port/`, user, pass, Log.get("client") { level = clientLevel })
  }

  ** Verify that when a server advertises OAUTH2 as an extra challenge
  ** alongside SCRAM:
  **   1. The hello 401 header contains both challenges.
  **   2. A non-interactive client still authenticates via SCRAM.
  Void verifyMultiChallenge()
  {
    // base64url-encoded values per Haystack syntax rules:
    //   issuer   → https://example.com
    //   clientId → test-client
    issuer   := "aHR0cHM6Ly9leGFtcGxlLmNvbQ"
    clientId := "dGVzdC1jbGllbnQ"

    // spin up a fresh server that appends the OAUTH2 extra challenge
    oauth2Extras := [AuthMsg("oauth2", ["issuer": issuer, "clientId": clientId])]
    Service oauthWisp := Slot.findMethod("wisp::WispService.testSetup").call(TestMod(oauth2Extras))
    oauthWisp.start
    oauthWisp->waitUntilListening
    Int oauthPort := oauthWisp->httpPort
    oauthUri := `http://localhost:$oauthPort/`

    try
    {
      // --- raw HELLO → 401 must carry SCRAM + OAUTH2 challenges --------
      hello := WebClient(oauthUri)
      hello.reqHeaders["Authorization"] =
        AuthMsg("hello", ["username": AuthUtil.toBase64("sally")]).toStr
      hello.writeReq.readRes
      verifyEq(hello.resCode, 401)
      header := hello.resHeaders["WWW-Authenticate"]
      hello.close
      msgs := AuthMsg.listFromStr(header)
      verifyEq(msgs.size, 2)
      verifyEq(msgs[0].scheme, "scram")
      verifyEq(msgs[1].scheme, "oauth2")
      verifyEq(msgs[1].param("issuer"),   issuer)
      verifyEq(msgs[1].param("clientId"), clientId)

      // --- non-interactive client must select SCRAM and succeed -------
      cx := AuthClientContext.open(
        oauthUri, "sally", "pass-sally",
        Log.get("client") { level = clientLevel })
      verify(cx.isAuthenticated)
      verifyEq(cx.headers["Authorization"], "bearer authToken=tok-sally")

      // --- non-interactive, OAUTH2-first header: still picks SCRAM -----
      // Confirm non-interactive clients skip oauth2 regardless of header order.
      scramMsg  := msgs[0]
      oauth2Msg := msgs[1]
      verifyEq(AuthClientContext.selectChallenge([oauth2Msg, scramMsg], false).scheme, "scram")
      verifyEq(AuthClientContext.selectChallenge([scramMsg, oauth2Msg], false).scheme, "scram")

      // --- interactive client: OAUTH2 selected regardless of position ----------
      verifyEq(AuthClientContext.selectChallenge([scramMsg, oauth2Msg], true).scheme, "oauth2")
      verifyEq(AuthClientContext.selectChallenge([oauth2Msg, scramMsg], true).scheme, "oauth2")
    }
    finally oauthWisp.stop
  }

  ** OAuth2Scheme.decodeParams must base64url-decode only the params listed in
  ** OAuth2Scheme.base64Params and forward all other params verbatim.
  Void verifyOauth2ParamDecode()
  {
    issuerPlain   := "https://example.com"
    clientIdPlain := "haystack-cli"
    scopesPlain   := "openid profile email"

    // Simulate the wire params map (base64-encoded keys mixed with plain pass-throughs)
    wireParams := Str:Str[
      "issuer":       AuthUtil.toBase64(issuerPlain),
      "clientId":     AuthUtil.toBase64(clientIdPlain),
      "scopes":       AuthUtil.toBase64(scopesPlain),
      "redirectPort": "9090",   // plain integer — must NOT be base64-decoded
    ]

    decoded := OAuth2Scheme.decodeParams(wireParams)
    verifyEq(decoded["issuer"],       issuerPlain)
    verifyEq(decoded["clientId"],     clientIdPlain)
    verifyEq(decoded["scopes"],       scopesPlain)
    verifyEq(decoded["redirectPort"], "9090")

    // unknown future params not in the allowlist are also passed through verbatim
    decoded2 := OAuth2Scheme.decodeParams(Str:Str[
      "issuer":       AuthUtil.toBase64(issuerPlain),
      "unknownParam": "rawValue",
    ])
    verifyEq(decoded2["issuer"],       issuerPlain)
    verifyEq(decoded2["unknownParam"], "rawValue")
  }


}

**************************************************************************
** TestMod
**************************************************************************

internal const class TestMod : WebMod
{
  new make(AuthMsg[] extras := AuthMsg[,]) { this.extras = extras }
  const AuthMsg[] extras

  override Void onService()
  {
    cx := TestServerContext(extras)
    user := cx.onService(req, res)
    if (user == null) return
    res.headers["Content-Type"] = "text/plain"
    res.out.w(req.uri.queryStr)
  }
}

**************************************************************************
** TestServerContext
**************************************************************************

internal class TestServerContext : AuthServerContext
{
  new make(AuthMsg[] extras := AuthMsg[,]) { this.extras = extras }
  AuthMsg[] extras

  override const Log log := Log.get("server") { level = RoundtripTest.serverLevel }

  override AuthMsg[] extraChallenges() { extras }

  override Str login()
  {
    "tok-$user.username"
  }

  override Obj? sessionByAuthToken(Str authToken)
  {
    if (!authToken.startsWith("tok-")) return null
    return userByUsername(authToken[4..-1])
  }

  override Str? userSecret()
  {
    ((TestAuthUser)userByUsername(user.username)).secret
  }

  override AuthUser? userByUsername(Str username)
  {
    switch (username[0])
    {
      case 'a':
      case 's':
        return toScramUser(username)
      case 'h': return toHmacUser(username)
      case 'b': return toBasicUser(username)
      case 'p': return toPlaintextUser(username)
      case 'x': return toPlaintextUser(username, "x-plaintext")
      default:  return null
    }
  }

  private AuthUser toScramUser(Str user)
  {
    pass   := "pass-$user"
    salt   := "salt-$user" // this must be valid base64uri
    scram  := ScramKey.gen(["hash": "SHA-256", "salt": salt.toBuf, "c": 100])
    msg    := scram.toAuthMsg
    return TestAuthUser(user, msg.scheme, msg.params, scram.toSecret(pass))
  }

  private AuthUser toHmacUser(Str user)
  {
    pass   := "pass-$user"
    salt   := "salt-$user"
    salt64 :=  Buf.fromBase64(salt).toBase64
    hash   := "SHA-1"
    secret := "$user:$salt64".toBuf.hmac(hash, pass.toBuf).toBase64
    return TestAuthUser(user, "hmac", ["salt":salt, "hash":hash], secret)
  }

  private AuthUser toBasicUser(Str user)
  {
    pass := "pass-$user"
    return TestAuthUser(user, "basic", [:], pass)
  }

  private AuthUser toPlaintextUser(Str user, Str scheme := "plaintext")
  {
    secret := "pass-$user"
    return TestAuthUser(user, scheme, [:], secret)
  }
}

**************************************************************************
** TestAuthUser
**************************************************************************

internal const class TestAuthUser : AuthUser
{
  new make(Str u, Str s, Str:Str p, Str x) : super(u, s, p) { secret = x }
  const Str secret
}

