//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 May 2021  Brian Frank  Creation
//

using web
using auth
using haystack
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
    if (s != null) return authenticated(s)
    if (res.isCommitted) return null

    // check for authenticated session via Authorization bearer token
    // or perform standard Haystack authentication pipeline steps
    s = checkAuthorization
    if (s != null) return authenticated(s)
    if (res.isCommitted) return null

    // check for tunnel cluster authentication
    s = checkCluster
    if (s != null) return authenticated(s)
    if (res.isCommitted) return null

    // not authenticated, redirect to login page
    res.redirect(lib.loginUri)
    return null
  }

  ** Called when request maps to an authenticated session
  private HxContext authenticated(HxUserSession session)
  {
    // refresh session and construct context
    user := session.isCluster ? session.user : lib.read(session.user.id)
    session.touch(user)
    cx := rt.context.createSession(session)
    cx.stash["attestKey"] = session.attestKey
    return cx
  }

  ** Check if cookies provide an valid session token
  private HxUserSession? checkCookie()
  {
    // check if session cookie was passed in request
    key := req.cookies[lib.cookieName]
    if (key == null) return null

    // check if cookie maps to a live session
    session := lib.sessions.get(key, false)
    if (session == null) return null

    // check if we have a attestation key
    attestKey := req.headers["Attest-Key"]
    if (attestKey != null)
    {
      // verify attestation key against session
      if (session.attestKey != attestKey)
      {
        res.sendErr(400, "Invalid Attest-Key")
        return null
      }
    }
    else
    {
      // if no attestation then don't trust anything but GET
      if (!req.isGet)
      {
        res.sendErr(400, "Attest-Key header required")
        return null
      }
    }

    // we have a valid session
    return session
  }

  ** Check if Authorization header provides an valid session token.
  ** Or if defined then peform standard Haystack auth pipeline.
  private HxUserSession? checkAuthorization()
  {
    // if the Authorization header specified use standard auth pipeline
    if (req.headers.containsKey("Authorization"))
      return HxUserAuthServerContext(lib).onService(req, res)

    // auto login superuser for testing
    if (lib.noAuth)
      return lib.login(req, res, HxUserImpl(rt.db.read(Filter("user and userRole==\"su\""))))

    // redirect to login
    return null
  }

  private HxUserSession? checkCluster()
  {
    // if this is a cluster tunneled request then the stash defines
    // the node, username, session key, and attest key
    username := req.stash["clusterUsername"] as Str
    if (username == null) return null
    node := req.stash["clusterNode"]
    sessionKey := req.stash["clusterSessionKey"] as Str
    attestKey := req.stash["clusterAttestKey"] as Str
    if (node == null || sessionKey == null || attestKey == null) return null

    // get user which cached using cluster stashing
    cluster := rt.services.get(HxClusterService#, false) as HxClusterService
    if (cluster == null) return null
    user := cluster.stashedUser(node, username)

    // create cluster session
    session := lib.sessions.openCluster(req, sessionKey, attestKey, user)
    return session
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
    if (user == null) return AuthUser.genFake(username)

    msg := HxUserUtil.dictToAuthMsg(user.meta->userAuth)
    return AuthUser(user.username, msg)
  }

  override Obj? sessionByAuthToken(Str authToken)
  {
    lib.sessions.get(authToken, false)
  }

  override Str? userSecret()
  {
    hxUser := lib.read(user.username, false)
    if (hxUser == null) return null
    return rt.db.passwords.get(hxUser.id.id)
  }

  override Str login()
  {
    lib.login(req, res, lib.read(user.username)).key
  }

  override Void onAuthErr(AuthErr err)
  {
    res.headers["x-hx-login-err"] = err.resMsg
  }
}

