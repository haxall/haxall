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
using hxm

**
** User library authentication pipeline.
**
internal class HxUserAuth
{
  new make(HxUserExt ext, WebReq req, WebRes res)
  {
    this.rt  = ext.rt
    this.ext = ext
    this.req = req
    this.res = res
  }

  const Runtime rt

@Deprecated Runtime proj() { rt }

  const HxUserExt ext

  WebReq req { private set }

  WebRes res { private set }

  ** Authenticate the request and return a new context.  If request
  ** is not authenticated then redirect to login and return null.
  UserSession? authenticate()
  {
    // check for tunnel cluster authentication
    s := checkCluster
    if (s != null) return authenticated(s)
    if (res.isCommitted) return null

    // check for authenticated session in cookie
    s = checkCookie
    if (s != null) return authenticated(s)
    if (res.isCommitted) return null

    // check for authenticated session via Authorization bearer token
    // or perform standard Haystack authentication pipeline steps
    s = checkAuthorization
    if (s != null) return authenticated(s)
    if (res.isCommitted) return null

    // not authenticated, redirect to login page
    res.redirect(ext.loginUri)
    return null
  }

  ** Called when request maps to an authenticated session
  private UserSession authenticated(HxUserSession session)
  {
    // refresh session and construct context
    user := session.isCluster ? session.user : ext.read(session.user.id)
    session.touch(user)
    return session
  }

  ** Check if cookies provide an valid session token
  private HxUserSession? checkCookie()
  {
    // check if session cookie was passed in request
    key := req.cookies[ext.cookieName]
    if (key == null) return null

    // check if cookie maps to a live session
    session := ext.sessions.get(key, false)
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
      return HxUserAuthServerContext(ext).onService(req, res)

    // auto login superuser for testing
    if (ext.noAuth)
      return ext.login(req, res, HxUser(proj.db.read(Filter("user and userRole==\"su\""))))

    // redirect to login
    return null
  }

  private HxUserSession? checkCluster()
  {
    // if this is a cluster tunneled request then the stash defines
    // the node, username, session key, and attest key
    sessionKey := req.stash["clusterSessionKey"] as Str
    if (sessionKey == null) return null

    // get username - used by both code paths below
    username := req.stash["clusterUsername"] as Str
    if (username == null) return null

    // lookup session
    session := ext.sessions.get(sessionKey, false)
    if (session != null)
    {
      // verify username matches this session
      if (session.user.username != username)
        throw Err("Session user mismatch $session.user != $username")
      return session
    }

    // need to create new session for this cluster user
    else
    {
      // get rest of stashed cluster data
      node := req.stash["clusterNode"]
      attestKey := req.stash["clusterAttestKey"] as Str
      if (node == null || attestKey == null) return null

      // get user which cached using cluster stashing
      cluster := ext.sys.cluster(false)
      if (cluster == null) return null
      user := cluster.stashedUser(node, username)

      // create cluster session
      session = ext.sessions.openCluster(req, sessionKey, attestKey, user)
      return session
    }
  }

}

**************************************************************************
** HxUserAuthServerContext
**************************************************************************

internal class HxUserAuthServerContext : AuthServerContext
{
  new make(HxUserExt ext) { this.rt = ext.rt; this.ext = ext }

  const Runtime rt

@Deprecated Proj proj() { rt }

  const HxUserExt ext

  override Log log() { ext.log }

  override AuthUser? userByUsername(Str username)
  {
    user := ext.read(username, false)
    if (user == null) return AuthUser.genFake(username)

    msg := HxUserUtil.dictToAuthMsg(user.meta->userAuth)
    return AuthUser(user.username, msg)
  }

  override Obj? sessionByAuthToken(Str authToken)
  {
    ext.sessions.get(authToken, false)
  }

  override Str? userSecret()
  {
    hxUser := ext.read(user.username, false)
    if (hxUser == null) return null
    return proj.db.passwords.get(hxUser.id.id)
  }

  override Str login()
  {
    ext.login(req, res, ext.read(user.username)).key
  }

  override Void onAuthErr(AuthErr err)
  {
    res.headers["x-hx-login-err"] = err.resMsg
  }
}

