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
    port = wisp->httpPort
  }

  Void closeServer()
  {
    wisp.stop
  }

  AuthClientContext openClient(Str user, Str pass)
  {
    AuthClientContext.open(`http://localhost:$port/`, user, pass, Log.get("client")  { level = clientLevel })
  }
}

**************************************************************************
** TestMod
**************************************************************************

internal const class TestMod : WebMod
{
  override Void onService()
  {
    /* handle basic as special test case
    if (req.headers.get("Authorization", "").lower.startsWith("basic "))
    {
      s := Buf.fromBase64(req.headers["Authorization"][6..-1]).readAllStr
      u := s[0..<s.index(":")]
      p := s[s.index(":")+1..-1]
      user := cx.userByUsername(u) as TestAuthUser
      if (user == null || user.secret != p)
        return cx.sendRes(res, 403, "Auth failed!")
    }
    */

    cx := TestServerContext()
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
  override const Log log := Log.get("server") { level = RoundtripTest.serverLevel }

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