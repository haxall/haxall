//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 May 2021  Brian Frank  Creation
//

using web
using auth
using hx

**
** User library authentication pipeline.
**
internal class HxUserAuth
{
  new make(HxUserLib lib, WebReq req, WebRes res)
  {
    this.rt = lib.rt
    this.lib = lib
    this.req = req
    this.res = res
  }

  const HxRuntime rt

  const HxUserLib lib

  WebReq req { private set }

  WebRes res { private set }

  ** Authenticate the request and return a new context.  If request
  ** is not authenticated then redirect to login and return null.
  HxContext? authenticate()
  {
    // check for authenticated session in cookie
    s := checkCookie
    if (res.isCommitted) return null
    if (s != null) return authenticated(s)

    // check for authenticated session via Authorization bearer token
    // or perform standard Haystack authentication pipeline steps
    s = checkAuthorization
    if (s != null) return authenticated(s)

    // not authenticated, redirect to login page
    res.redirect(lib.loginUri)
    return null
  }

  ** Called when request maps to an authenticated session
  private HxContext authenticated(HxSession session)
  {
    // refresh session and construct context
    user := lib.read(session.user.id)
    session.touch(user)
    return rt.makeContext(user)
  }

  ** Check if cookies provide an valid session token
  private HxSession? checkCookie()
  {
    // check if session cookie was passed in request
    key := req.cookies[lib.cookieName]
    if (key == null) return null

    // check if cookie maps to a live session
    session := lib.sessions.get(key, false)
    if (session == null) return null

    // check if we have a attestation key
    attestKey := req.headers["X-Attest-Key"]
    if (attestKey != null)
    {
      // verify attestation key against session
      if (session.attestKey != attestKey)
      {
        res.sendErr(400, "Invalid X-Attest-Key")
        return null
      }
    }
    else
    {
      // if no attestation then don't trust anything but GET
      if (!req.isGet)
      {
        res.sendErr(400, "X-Attest-Key required")
        return null
      }
    }

    // we have a valid session
    return session
  }

  ** Check if Authorization header provides an valid session token.
  ** Or if defined then peform standard Haystack auth pipeline.
  private HxSession? checkAuthorization()
  {
    if (!req.headers.containsKey("Authorization")) return null
    return HxUserAuthServerContext(lib).onService(req, res)
  }
}

**************************************************************************
** HxUserAuthServerContext
**************************************************************************

internal class HxUserAuthServerContext : AuthServerContext
{
  new make(HxUserLib lib) { this.rt = lib.rt; this.lib = lib }

  const HxRuntime rt

  const HxUserLib lib

  override Log log() { lib.log }

  override AuthUser? userByUsername(Str username)
  {
    user := lib.read(username, false)
    if (user == null) return null

    msg := HxUserUtil.dictToAuthMsg(user.meta->userAuth)
    return AuthUser(user.username, msg)
  }

  override Obj? sessionByAuthToken(Str authToken)
  {
    lib.sessions.get(authToken, false)
  }

  override Str? userSecret()
  {
    hxUser := lib.read(user.username)
    return rt.db.passwords.get(hxUser.id.id)
  }

  override Str login()
  {
    hxUser := lib.read(user.username)
    session := lib.sessions.open(req, hxUser)
    addSessionCookie(session)
    return session.key
  }

  private Void addSessionCookie(HxSession session)
  {
    overrides := Field:Obj?[:]

    // we use enough built in security checks with the attest key
    // that we don't need to require the sameSite strict flag
    overrides[Cookie#sameSite] = null

    // if the public facing HTTP server is using HTTPS then force secure flag
    if (rt.httpUri.scheme == "https") overrides[Cookie#secure] = true

    // construct the session cookie
    cookie := Cookie.makeSession(lib.cookieName, session.key, overrides)

    res.cookies.clear
    res.cookies.add(cookie)
  }
}

