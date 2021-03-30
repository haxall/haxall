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
** AuthClientContext used to manage the process for authenticating
** with HTTP/HTTPS server to open an `AuthClient`.
**
class AuthClientContext
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Constructor. Must set `uri`, `user`, `pass`, and `log`
  new make(|This| f)
  {
    f(this)
  }

//////////////////////////////////////////////////////////////////////////
// State
//////////////////////////////////////////////////////////////////////////

  ** URI used to open the connection
  const Uri uri

  ** Username used for authentication
  const Str user

  ** Plaintext password for authentication
  Str? pass

  ** Logging instance
  const Log log

  ** User agent string
  const Str? userAgent := "SkyArc/$typeof.pod.version"

  ** Timeout for WebClient sockets
  @NoDoc const Duration timeout := 1min

  ** Headers we wish to use for AuthClient requests
  Str:Str headers := [:]

  ** Have we successfully authenticated to the server
  Bool isAuthenticated { private set }

  ** Stash allows you to store state between messages while
  ** authenticating with the server.
  Str:Obj? stash := [:] { private set }

//////////////////////////////////////////////////////////////////////////
// Open
//////////////////////////////////////////////////////////////////////////

  ** Open the authenticated session. On failure an exception will
  ** be raised.  If successful then return this and then use `prepare`
  ** to use authenticated WebClients to the server
  This open()
  {
    try
    {
      // special user bypasses Haystack authentication and sets Bearer token directly
      // from the given password
      if (openBearer) return this

      // send initial hello message
      c := prepare(WebClient(uri))
      c.reqHeaders["Authorization"] = AuthMsg("hello", ["username":AuthUtil.toBase64(user)]).toStr
      content := get(c)

      // first try standard authentication via RFC 7235 process
      if (openStd(c)) return success(c)

      // check if we have a 200
      if (c.resCode == 200) return success(c)

      // try non-standard schemes
      schemes := AuthScheme.list
      for (i := 0; i < schemes.size; ++i)
        if (schemes[i].onClientNonStd(this, c, content))
          return success(c)

      // give up
      resCode := c.resCode
      resServer := c.resHeaders["Server"]
      if (resCode / 100 >= 4) throw IOErr("HTTP error code: $resCode") // 4xx or 5xx
      throw AuthErr("No suitable auth scheme for: $resCode $resServer")
    }
    finally
    {
      this.pass = null
      this.stash.clear
    }
  }

  ** Get a required rsponse header
  Str resHeader(WebClient c, Str name)
  {
    c.resHeaders[name] ?: throw err("Missing required header: $name")
  }

  ** Standard error to raise
  AuthErr err(Str msg) { AuthErr(msg) }

  ** Clear password and return this
  private This success(WebClient c)
  {
    addCookiesToHeaders(c)
    isAuthenticated = true
    return this
  }

  ** If the web client has Set-Cookie header, then add those
  ** cookies into the 'headers' field for future web requests
  private Void addCookiesToHeaders(WebClient c)
  {
    if (c.cookies.isEmpty || this.headers.containsKey("Cookie")) return
    s := StrBuf()
    c.cookies.each |cookie| { s.join("$cookie.name=$cookie.val", ";") }
    this.headers["Cookie"] = s.toStr
  }

  ** Check if special bearer user is being used
  private Bool openBearer()
  {
    if (user != "auth-bearer-token") return false

    // set the bearer token directly from the given password
    this.headers["Authorization"] = AuthMsg("bearer", ["authToken": pass]).toStr
    isAuthenticated = true
    return true
  }

  ** Attempt standard authentication via Haystack/RFC 7235
  private Bool openStd(WebClient c)
  {
    // must be 401 challenge with WWW-Authenticate header
    if (c.resCode != 401) return false
    wwwAuth := c.resHeaders["WWW-Authenticate"]
    if (wwwAuth == null) return false

    // don't use this mechanism for Basic which we
    // handle as a non-standard scheme because the headers
    // don't fit nicely into our restricted AuthMsg format
    if (wwwAuth.lower.startsWith("basic")) return false

    // process res/req messages until we have 200 or non-401 failure
    AuthScheme? scheme
    for (loopCount := 0; true; ++loopCount)
    {
      // sanity check that we don't loop too many times
      if (loopCount > 5) throw err("Loop count exceeded")

      // parse the WWW-Auth header and use the first scheme
      header  := resHeader(c, "WWW-Authenticate")
      resMsgs := AuthMsg.listFromStr(header)
      resMsg  := resMsgs.first
      scheme  = AuthScheme.find(resMsg.scheme)

      // let scheme handle handle message
      reqMsg := scheme.onClient(this, resMsg)

      // send request back to the server
      c = prepare(WebClient(uri))
      c.reqHeaders["Authorization"] = reqMsg.toStr
      get(c)

      // 200 means we are done, 401 means keep looping,
      // consider anything else a failure
      if (c.resCode == 200) break
      if (c.resCode == 401) continue
      throw err("$c.resCode $c.resPhrase")
    }

    // init the bearer token
    authInfo := resHeader(c, "Authentication-Info")
    authInfoMsg := AuthMsg.fromStr("bearer $authInfo")

    // callback to scheme for client success
    scheme.onClientSuccess(this, authInfoMsg)

    // only keep authToken parameter for Authorization header
    authInfoMsg = AuthMsg("bearer", ["authToken": authInfoMsg.param("authToken")])
    this.headers["Authorization"] = authInfoMsg.toStr
    return true
  }

//////////////////////////////////////////////////////////////////////////
// HTTP Messaging
//////////////////////////////////////////////////////////////////////////

  ** Prepare a WebClient instance with the auth cookies/headers
  WebClient prepare(WebClient c)
  {
    c.followRedirects = false
    c.socketOptions.connectTimeout = this.timeout
    c.socketOptions.receiveTimeout = this.timeout
    c.reqHeaders.setAll(this.headers)
    if (userAgent != null) c.reqHeaders["User-Agent"] = userAgent
    return c
  }

  ** Make GET request to the server, return response content
  Str? get(WebClient c)
  {
    send(c, null)
  }

  ** Make POST request to the server, return response content
  Str? post(WebClient c, Str content)
  {
    send(c, content)
  }

  private Str? send(WebClient c, Str? post)
  {
    try
    {
      // if posting, translate to body buffer and setup web client
      Buf? body
      if (post != null)
      {
        body = Buf().print(post).flip
        c.reqMethod = "POST"
        c.reqHeaders["Content-Length"] = body.size.toStr
        if (c.reqHeaders["Content-Type"] == null)
          c.reqHeaders["Content-Type"] = "text/plain; charset=utf-8"
      }

      // debug request
      debugCount := debugReq(log, c, post)

      // make request
      if (post == null)
      {
        c.writeReq.readRes
      }
      else
      {
        c.writeReq
        c.reqOut.writeBuf(body).close
        c.readRes
      }

      // read response
      Str? res := null
      resType := c.resHeaders["Content-Type"]
      if (resType != null) res = c.resIn.readAllStr

      // debug  response
      debugRes(log, debugCount, c, res)

      return res
    }
    finally c.close
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  static const AtomicInt debugCounter := AtomicInt()

  static Int debugReq(Log? log, WebClient c, Str? content := null)
  {
    if (log == null || !log.isDebug) return 0
    count := debugCounter.getAndIncrement
    s := StrBuf()
    s.add("> [$count]\n")
    s.add("$c.reqMethod $c.reqUri\n")
    c.reqHeaders.each |v, n| { s.add("$n: $v\n") }
    if (content != null) s.add(content.trimEnd).add("\n")
    log.debug(s.toStr)
    return count
  }

  static Void debugRes(Log? log, Int count, WebClient c, Str? content := null)
  {
    if (log == null || !log.isDebug) return
    s := StrBuf()
    s.add("< [$count]\n")
    s.add("$c.resCode $c.resPhrase\n")
    c.resHeaders.each |v, n| { s.add("$n: $v\n") }
    if (content != null) s.add(content.trimEnd).add("\n")
    log.debug(s.toStr)
  }

//////////////////////////////////////////////////////////////////////////
// Main
//////////////////////////////////////////////////////////////////////////

  ** Debug command line tester
  static Void main(Str[] args)
  {
    if (args.size < 3) { echo("usage: <uri> <user> <pass>"); return }
    log := Log.get("auth")
    log.level = LogLevel.debug
    cx := AuthClientContext { it.uri=args[0].toUri; it.user=args[1]; it.pass=args[2]; it.log=log }
    cx.open
    echo("--- AuthContext.open success! ---\n")

    res := cx.get(cx.prepare(WebClient(cx.uri)))
  }
}