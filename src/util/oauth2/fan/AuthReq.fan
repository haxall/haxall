//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 May 20  Matthew Giannini  Creation
//   27 Jan 22  Matthew Giannini  Port to Haxall
//

using concurrent
using inet
using web
using wisp
using [java] java.awt::Desktop
using [java] java.net::URI

**
** Base class for Authorization Code requests
**
const abstract class AuthReq
{
  new make(Uri authUri, Str clientId, |This|? f := null)
  {
    f?.call(this)
    this.authUri  = authUri
    this.clientId = clientId
  }

  const Uri authUri

  const Str clientId

  const Uri? redirectUri

  const Str[]? scopes

  const [Str:Str] customParams := [:]

  virtual Str:Str build()
  {
    params := customParams.dup
    params["client_id"]     = clientId
    params["response_type"] = responseType
    if (redirectUri != null) params["redirect_uri"] = redirectUri.toStr
    if (scopes != null) params["scope"] = scopes.join(" ")
    return params
  }

  abstract Str responseType()

  abstract Str:Str authorize(Str:Str flowParams)
}

**************************************************************************
** LoopbackAuthReq
**************************************************************************

**
** Handles the Authorization Code request using a loopback HTTP listener.
**
** RFC 8252 sec 7.3: the 'redirectUri' must have a loopback host (127.0.0.1
** or localhost) and a concrete port.  OAuthClient.open pre-resolves an
** ephemeral port via a throwaway TcpListener so this class always receives
** a fully specified URI and uses it verbatim.
**
** RFC 6749 sec 4.1.3: the token endpoint must receive the identical
** redirect_uri used in the authorize request.
**
const class LoopbackAuthReq : AuthReq
{
  new make(Uri authUri, Str clientId, |This|? f := null) : super(authUri, clientId, f)
  {
    if (redirectUri == null) throw ArgErr("Must set redirectUri")
    checkHost
  }

  override const Str responseType := "code"

  **
  ** How long to wait for the user to complete the browser login (including
  ** any multifactor authentication steps) before timing out.  Defaults to
  ** 3 minutes; increase this for environments with slow MFA delivery or
  ** manual enrollment steps.
  **
  ** Example: set to 5 minutes via the it-block constructor:
  **   req := LoopbackAuthReq(authUri, clientId) { it.loginTimeout = 5min }
  **
  const Duration loginTimeout := 3min

  private Void checkHost()
  {
    switch (redirectUri.host.lower)
    {
      case "127.0.0.1":
      case "localhost":
      case IpAddr.local.toStr:
        return
    }
    throw ArgErr("Invalid host [${redirectUri.host}] for ${typeof.name}. Use '127.0.0.1' instead.")
  }

  override Str:Str authorize(Str:Str flowParams)
  {
    // bind the loopback listener to redirectUri.host only (RFC 8252 sec 8.3)
    mod  := LoopbackMod()
    wisp := WispService { it.addr = IpAddr(redirectUri.host); it.httpPort = redirectUri.port; it.root = mod }.start
    try
    {
      params := this.build
      params["state"] = Buf.random(16).toBase64Uri
      params.addAll(flowParams)
      Desktop.getDesktop().browse(URI(authUri.plusQuery(params).encode))

      // wait for the AS redirect; verify CSRF state
      authRes := mod.authRes.get(loginTimeout)
      return verify(authRes, params["state"])
    }
    finally wisp.stop
  }

  private Str:Str verify(Str:Str authRes, Str state)
  {
    if (authRes["state"] != state) throw Err("Invalid state")
    return authRes
  }
}

**************************************************************************
** LoopbackMod
**************************************************************************

internal const class LoopbackMod : WebMod
{
  new make() { }

  const Future authRes := Future.makeCompletable

  override Void onGet()
  {
    if (checkError) return

    res.headers["Content-Type"] = "text/html; charset=utf-8"
    out := res.out
    out.html
      .head.title.w("Auth Success").titleEnd.headEnd
      .body
        .h1.w("Authorization Granted").h1End
        .p.w("You may close this page").pEnd
      .bodyEnd
    .htmlEnd

    authRes.complete(req.uri.query)
  }

  private Bool checkError()
  {
    q     := req.uri.query
    error := q["error"]
    if (error == null) return false

    authRes.completeErr(AuthReqErr(q))

    res.headers["Content-Type"] = "text/html; charset=utf-8"

    desc := q["error_description"] ?: "No further details available"
    out := res.out
    out.html
      .head.title.w("Auth Error").titleEnd.headEnd
      .body
        .h1.w("Authorization Error").h1End
        .p.w("${error}: ${desc}").pEnd
      .bodyEnd
    .htmlEnd

    return true
  }
}

**************************************************************************
** AuthReqErr
**************************************************************************

const class AuthReqErr : Err
{
  new make(Str:Str params, Err? cause := null) : super(params["error"], cause)
  {
    this.params = params
  }

  ** Raw error information
  const Str:Str params

  Str error() { params["error"] }

  Str desc() { params["error_description"] ?: "No description available" }

  override Str toStr()
  {
    "[$error] $desc"
  }
}