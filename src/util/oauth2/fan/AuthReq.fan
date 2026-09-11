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
** The authorization server must be configured to redirect to the loopback
** address (127.0.0.1 or localhost).  This class:
**   1. Starts a WispService on the port from `redirectUri`, or an OS-assigned
**      ephemeral port when no port is specified (RFC 8252 §7.3).
**   2. Builds the effective `redirect_uri` using the actual bound port.
**   3. Opens the authorization URL in the system browser.
**   4. Waits up to 2 minutes for the AS to redirect back with an auth code.
**   5. Verifies the `state` parameter to prevent CSRF.
**   6. Returns a result map that includes `redirect_uri` so that the token
**      endpoint receives the exact same URI (RFC 6749 §4.1.3).
**
const class LoopbackAuthReq : AuthReq
{
  new make(Uri authUri, Str clientId, |This|? f := null) : super(authUri, clientId, f)
  {
    if (redirectUri == null) throw ArgErr("Must set redirectUri")
    checkHost
  }

  override const Str responseType := "code"

  private Void checkHost()
  {
    switch (redirectUri.host.lower)
    {
      case "127.0.0.1":
      case "localhost":
      case IpAddr.local.toStr:
        return
    }
    throw ArgErr("Invalid host [$redirectUri.host] for ${typeof.name}. Use '127.0.0.1' instead.")
  }

  override Str:Str authorize(Str:Str flowParams)
  {
    // Use the caller-specified port when present in redirectUri, otherwise let
    // the OS assign an ephemeral port (httpPort=-1).  RFC 8252 §7.3 recommends
    // ephemeral ports, but some AS configurations require a fixed registered port.
    requestedPort := redirectUri.port ?: -1
    mod  := LoopbackMod()
    wisp := WispService { it.httpPort = requestedPort; it.root = mod }.start
    try
    {
      // Wait until Wisp is actually listening so we can read the bound port.
      // waitUntilListening blocks until isListening is true, at which point the
      // WispService has already setConst'd httpPort to the OS-assigned value.
      wisp.waitUntilListening
      port := wisp.httpPort ?: throw Err("WispService did not assign an httpPort after listening")

      // Build the effective redirect_uri with the actual bound port.
      effectiveRedirect := "http://127.0.0.1:${port}/callback"

      // Build the authorize request params, replacing redirect_uri with the
      // port-resolved value and adding PKCE + state.
      params := this.build
      params["redirect_uri"] = effectiveRedirect
      params["state"]        = Buf.random(16).toBase64Uri
      params.addAll(flowParams)

      Desktop.getDesktop().browse(URI(authUri.plusQuery(params).encode))

      authRes  := mod.authRes.get(2min)
      verified := verify(authRes, params["state"]).dup

      // Forward the effective redirect_uri so the token endpoint receives the
      // identical URI used in the authorize request (RFC 6749 §4.1.3).
      verified["redirect_uri"] = effectiveRedirect
      return verified
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
        .h1.w("Authorization Granted").h1
        .p.w("You may close this page").pEnd
      .bodyEnd
    .htmlEnd

    // complete the response future with the auth code
    authRes.complete(req.uri.query)
  }

  private Bool checkError()
  {
    q     := req.uri.query
    error := q["error"]
    if (error == null) return false

    // complete the response future with an error
    authRes.completeErr(AuthReqErr(q))

    res.headers["Content-Type"] = "text/html; charset=utf-8"

    desc := q["error_description"] ?: "No futher details available"
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