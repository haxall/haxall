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
** If the authorization server is configured to redirect to the localhost, then this
** class can be used to do an authorization request. It will open a browser window for the
** user to authorize access with the remote authorization server. It will spawn a
** web server on the localhost to handle the redirect that the authorization server
** will do after the authorization access is granted or denied. It granted, we grabe
** the authorization code from the spawned web server so that the authorization code
** grant flow can continue.
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
    params := this.build
    params["state"] = Buf.random(16).toBase64Uri
    params.addAll(flowParams)

    mod  := LoopbackMod()
    wisp := WispService {
      it.httpPort = redirectUri.port ?: 80
      it.root     = mod
    }.start

    try
    {
      uri := authUri.plusQuery(params)
      Desktop.getDesktop().browse(URI(uri.encode))

      authRes := mod.authRes.get(2min)
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

    errorUri := (q["error_uri"] as Str)?.toUri
    if (errorUri != null)
    {
      res.redirect(errorUri)
      return true
    }

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