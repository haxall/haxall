//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Apr 16  Brian Frank  Creation
//

using concurrent
using web

**
** AuthServerContext manages the server-side process for authenticating a user.
** It provides a set of abstract methods to plug into the application user database
** and session management.
**
abstract class AuthServerContext
{

//////////////////////////////////////////////////////////////////////////
// Plugin Methods
//////////////////////////////////////////////////////////////////////////

  ** Log to use for debugging and error reporting
  abstract Log log()

  ** Get an AuthUser for the user with the given username.
  **
  ** If null is returned, then the Haystack authentication will *immediately*
  ** stop without sending any response to the client. It is the responsibility of
  ** the code invoking the AuthServerContext to send an appropriate response in this
  ** case. This condition signals that given user is using some alternative form
  ** of authentication.
  **
  ** If the user doesn't exist, but you want a "fake" haystack authentication
  ** to occur, then return AuthUser.getFake.
  abstract AuthUser? userByUsername(Str username)

  ** Lookup user session by authToken or return null if invalid token
  abstract Obj? sessionByAuthToken(Str authToken)

  ** Lookup user's password hash string for validation
  ** or return null if the user should not be allowed to log in.
  abstract Str? userSecret()

  ** Return if the given user's secret matches what is stored
  virtual Bool authSecret(Str secret) { userSecret == secret }

  ** Login the current user successfully and return the authToken
  abstract Str login()

  ** Callback when a user fails a login attempt
  virtual Void onAuthErr(AuthErr err) { }

//////////////////////////////////////////////////////////////////////////
// Service
//////////////////////////////////////////////////////////////////////////

  ** User currently being being authenticated
  AuthUser? user { private set }

  ** Current web request
  WebReq? req { private set }

  ** Current web response
  WebRes? res { private set }

  ** Process authentication request. Return result of sessionByAuthToken
  ** if user is authenticated, otherwise send challenge message and return null
  Obj? onService(WebReq req, WebRes res)
  {
    Str? username := null
    try
    {
      // make req/res available to implementations
      this.req = req
      this.res = res

      // debug request and setup debugging
      isDebug := debugReq(req)

      // check for Authorization header
      header := req.headers["Authorization"]
      if (isDebug) debug("Auth header: $header")
      if (header == null) return sendRes(res, 400, "Missing Authorization header")

      // decode header according to RFC 7235 grammar
      reqMsg := AuthMsg.fromStr(header, false)
      if (isDebug) debug("Parse header: $reqMsg")
      if (reqMsg == null)
      {
        errMsg := header.lower.startsWith("basic") ?
          "Basic authentication not supported" :
          "Cannot parse Authorization header"
        return sendRes(res, 400, errMsg)
      }

      schemeName := reqMsg.scheme

      // if we have a bearer token, then validate it
      if ("bearer" == schemeName) return handleBearer(reqMsg)

      // user is base64 encoded into username or handshakeToken param
      username64 := reqMsg.param("username", false) ?: reqMsg.param("handshakeToken", false)
      if (isDebug) debug("Username64: $username64")
      if (username64 == null) return sendRes(res, 400, "Missing username or handshakeToken in Authorization header")

      // attempt to decode the username from base64
      try { username = AuthUtil.fromBase64(username64) } catch (Err e) {}
      if (isDebug) debug("Username: $username")
      if (username == null) return sendRes(res, 400, "Invalid base64 encoding of username param in Authorization header")

      // resolve user from its username
      user := userByUsername(username)
      if (isDebug) debug("User: $user")

      // immediately stop processing without sending a response if the user is null
      if (user == null) return null

      // handle hello message by routing to user's configured scheme, otherwise
      // verify the scheme matches the user's configured scheme
      if (schemeName == "hello") schemeName = user.scheme
      if (isDebug) debug("Scheme name: $schemeName")
      if (schemeName != user.scheme) return sendRes(res, 400, "Invalid auth scheme for user: $schemeName != $user.scheme")

      // initialize the server context
      this.user   = user

      // handle the scheme message
      resMsg := handleScheme(schemeName, reqMsg)
      if (resMsg == null) return sendRes(res, 400, "Unsupported scheme for Authorization header")
      if (isDebug) debug("Res msg: $resMsg")
      ok := resMsg.param("authToken", false) != null

      // send response back to client
      if (ok)
      {
        res.headers["Authentication-Info"] = resMsg.paramsToStr
        sendRes(res, 200, "Auth successful")
      }
      else
      {
        res.headers["WWW-Authenticate"] = resMsg.toStr
        sendRes(res, 401, "Auth challenge")
      }
      return null
    }
    catch (AuthErr e)
    {
      remoteAddr := AuthUtil.realIp(req)
      msg := "Login failed for user [${username}] from remote ip [$remoteAddr]: $e.msg"
      if (log.isDebug) log.debug(msg, e)
      else log.info(msg)
      onAuthErr(e)
      return sendRes(res, e.resCode, "Auth failed: $e.resMsg")
    }
  }

  private Obj? handleBearer(AuthMsg reqMsg)
  {
    authToken := reqMsg.param("authToken", false)
    if (isDebug) debug("Bearer token: $authToken")
    if (authToken != null)
    {
      session := sessionByAuthToken(authToken)
      if (isDebug) debug("Bearer session: $session")
      if (session != null) return session
    }
    return sendRes(res, 403, "Invalid or expired authToken")
  }

  ** Low-level callback to handle scheme messages. The default behavior is to
  ** lookup the AuthScheme and delegate handling of the request to it. But one could
  ** override this method to implement their own handling of auth messages without the
  ** use of an AuthScheme if they so desired.
  virtual protected AuthMsg? handleScheme(Str schemeName, AuthMsg reqMsg)
  {
    // resolve Fantom class to handle the scheme
    scheme := AuthScheme.find(schemeName, false)
    if (isDebug) debug("Scheme: ${scheme?.typeof}")
    if (scheme == null) return null

    AuthMsg? resMsg := null
    try { resMsg = scheme.onServer(this, reqMsg) } catch (UnsupportedErr e) { if (isDebug) e.trace }
    return resMsg
  }

  ** Callback to add in security related headers.
  ** By default we set the following headers:
  ** - Content-Security-Policy: 'self'
  ** - X-Frame-Options: SAMEORIGIN
  ** - Cache-Control: no-cache, no-store, private
  virtual protected Void addSecResHeaders()
  {
    res.headers["Cache-Control"] = "no-cache, no-store, private"
    res.headers["X-Frame-Options"] = "SAMEORIGIN"
    res.headers["Content-Security-Policy"] = "frame-ancestors 'self'"
  }

  internal Obj? sendRes(WebRes res, Int code, Str msg)
  {
    res.headers["Content-Length"]  = "0"
    addSecResHeaders
    if (isDebug) debugRes(res, code, msg)
    res.sendErr(code, msg)
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  Bool isDebug { private set }

  Void debug(Str msg)
  {
    if (!isDebug) throw Err("Wrap with if(isDebug)")
    if (msg.contains("password"))
    {
      r := Regex.fromStr("password=(.*)\\b?")
      m := r.matcher(msg)
      if (m.find) msg = msg.replace("password=${m.group(1)}", "password=<password>")
    }
    debugBuf.add(debugStep.toChar).add(") ").add(msg).addChar('\n')
    debugStep++
  }

  private Bool debugReq(WebReq req)
  {
    isDebug = log.isDebug
    if (!isDebug) return false

    debugCount = debugCounter.getAndIncrement
    s := debugBuf = StrBuf()
    s.add("> [$debugCount]\n")
    s.add("$req.method $req.uri\n")
    req.headers.each |v, n| { s.add("$n: $v\n") }
    log.debug(s.toStr)

    debugBuf = s.clear.add("< [$debugCount]\n")
    debugStep = 'a'
    return true
  }

  private Void debugRes(WebRes res, Int code, Str msg)
  {
    if (!isDebug) return
    s := debugBuf
    s.add("$code $msg\n")
    res.headers.each |v, n| { s.add("$n: $v\n") }
    log.debug(s.toStr)
  }

  static const AtomicInt debugCounter := AtomicInt()

  private Int debugCount
  private StrBuf? debugBuf
  private Int debugStep

}

**************************************************************************
** AuthUser
**************************************************************************

**
** AuthUser models the user information needed to perform
** server side authentication
**
const class AuthUser
{
  ** Generate "fake" scram response for an unknown user with the given username
  @NoDoc static AuthUser genFake(Str username)
  {
    // generate "fake" scram response for unknown user
    scram := ScramKey.gen([
      "hash": "SHA-256",
      "salt": Buf.fromBase64(AuthUtil.dummySalt(username))])
    return AuthUser(username, scram.toAuthMsg)
  }

  @NoDoc new makeMsg(Str username, AuthMsg msg) : this.make(username, msg.scheme, msg.params)
  {
  }

  new make(Str username, Str scheme, Str:Str params)
  {
    this.username = username
    this.scheme   = scheme
    this.params   = params
  }

  ** Username key
  const Str username

  ** Scheme name to use for authenticating this user
  const Str scheme

  ** Parameters to use for auth scheme
  const Str:Str params

  ** Return username
  override Str toStr() { username }

  ** Lookup a parameter by name
  Str? param(Str name, Bool checked := true)
  {
    val := params[name]
    if (val != null) return val
    if (checked) throw Err("AuthUser param not found: $name")
    return null
  }

}