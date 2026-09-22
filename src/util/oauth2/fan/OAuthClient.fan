//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Jun 20  Matthew Giannini  Creation
//   27 Jan 22  Matthew Giannini  Port to Haxall
//

using concurrent
using inet
using web
using util

**
** OAuthClient
**
const class OAuthClient
{

//////////////////////////////////////////////////////////////////////////
// Open
//////////////////////////////////////////////////////////////////////////

  ** Run the loopback OAuth 2.0 Authorization Code + PKCE login, called via
  ** reflection from 'auth::OAuth2Scheme'.  Returns the access token string or
  ** raises on failure.
  static Str open(Uri uri, Str:Str params, Log log)
  {
    issuer       := params.getChecked("issuer").toUri
    cid          := params.getChecked("clientId")
    scopes       := params["scopes"]                // optional
    redirectPort  := params["redirectPort"]?.toInt  // optional fixed loopback port
    loginTimeout  := params["loginTimeout"]         // optional Duration string, e.g. "5min"

    authUri  := params["authorizationEndpoint"]?.toUri
    tokenUri := params["tokenEndpoint"]?.toUri
    if (authUri == null || tokenUri == null)
    {
      AuthServerMetadata? meta := null
      try
        meta = AuthServerMetadata.discover(issuer)
      catch (IOErr e) {}
      base := AuthServerMetadata.normalize(issuer)
      if (authUri  == null) authUri  = meta != null ? meta.authorizationEndpoint : `${base}/oauth/authorize`
      if (tokenUri == null) tokenUri = meta != null ? meta.tokenEndpoint         : `${base}/oauth/token`
    }

    redirectUri := resolveRedirectUri(redirectPort)

    authReq := LoopbackAuthReq(authUri, cid)
    {
      it.redirectUri = redirectUri
      if (scopes != null) it.scopes = scopes.split(' ')
      if (loginTimeout != null) it.loginTimeout = Duration.fromStr(loginTimeout)
    }
    tokenReq := AuthCodeTokenReq(tokenUri)
    grant    := AuthCodeGrant(authReq, tokenReq)

    log.debug("""Opening browser to authenticate...
                  server: ${issuer}
                  authUri: ${authUri}
                  tokenUri: ${tokenUri}""")
    token := grant.run
    log.info("OAuth authentication successful")
    return token.accessToken
  }

  ** Bind a throwaway TcpListener to obtain an available loopback port, then
  ** close it so WispService can bind the same port.
  private static Uri resolveRedirectUri(Int? fixedPort)
  {
    if (fixedPort != null) return `http://127.0.0.1:${fixedPort}/callback`
    l := TcpListener()
    try
    {
      l.bind(IpAddr("127.0.0.1"), null)
      port := l.localPort
      return `http://127.0.0.1:${port}/callback`
    }
    finally l.close
  }

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Create a basic OAuthClient with the given access token. Token refresh is not
  ** supported.
  new make(AccessToken token)
  {
    this.tokenRef.val = token
  }

  ** Create an OAuthClient that supports token refresh.
  ** The tokenUri is the endpoint to use to refresh the token.
  ** The params must at least include the 'client_id' parameter.
  new makeRefreshable(AccessToken token, Uri tokenUri, Str:Str params)
  {
    this.tokenRef.val  = token
    this.tokenUri      = tokenUri
    this.refreshParams = params
    if (params["client_id"] == null) throw ArgErr("Must specify 'client_id' in params: ${params}")
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private static const Str:Str emptyHeaders := [:]

  protected AccessToken token() { tokenRef.val }
  private const AtomicRef tokenRef := AtomicRef()

  private const Uri? tokenUri
  private const Str:Str refreshParams := emptyHeaders

//////////////////////////////////////////////////////////////////////////
// Client
//////////////////////////////////////////////////////////////////////////

  ** Do an HTTP request with the given method (GET, PUT, etc.) to the given URI.  You can
  ** also pass additional headers to include with the request.  This method will handle
  ** OAuth token refresh.
  **
  ** If the 'req' parameter is non-null, it will be first be converted to a File
  ** as described below and then written as the request body (see WebClient.writeFile).
  **  - File: no conversion done, file is written as-is
  **  - Buf: converted to a File using Buf.toFile. The Content-Type will be
  **   'application/octet-stream'.
  **  - Map: encoded to JSON and written as a File with '.json' ext.
  **
  ** Returns a WebClient in a state where [web::WebClient.readRes]`web::WebClient.readRes`
  ** has been called and the [web::WebClient.resIn]`web::WebClient.resIn` is available
  ** for reading.
  WebClient call(Str method, Uri uri, Obj? req := null, [Str:Str] headers := emptyHeaders)
  {
    WebClient? c := null
    attempt := 1
    while (true)
    {
      c = doCall(method, uri, req, headers)

      if (c.resCode == 401 && attempt == 1) refreshToken
      else break

      ++attempt
    }
    return c
  }

  private WebClient doCall(Str method, Uri uri, Obj? req, [Str:Str] headers)
  {
    c := prepare(method, uri, headers)
    try
    {
      if (req == null) c.writeReq
      else c.writeFile(method, toFile(req))
      c.readRes
      return c
    }
    catch (IOErr err)
    {
      try
      {
        if (c.resCode == 0) throw err
        else throw OAuthErr(c)
      }
      finally c.close
    }
  }

  ** Utility to obtain a raw WebClient with uri, method, and headers set (including Bearer token).
  WebClient prepare(Str method, Uri uri, Str:Str headers := emptyHeaders)
  {
    c := WebClient(uri)
    c.reqMethod = method.upper
    c.reqHeaders.addAll(headers)
    c.reqHeaders["Authorization"] = "Bearer ${token.accessToken}"
    return c
  }

  @NoDoc Void refreshToken()
  {
    if (tokenUri == null || token.refreshToken == null) return

    c := WebClient(tokenUri)
    try
    {
      params := refreshParams.dup
      params.addAll([
        "grant_type":   "refresh_token",
        "refresh_token": token.refreshToken,
      ])
      c.postForm(params)

      json := readJson(c.resStr)
      // force add the refresh_token into the new access token for future refreshes
      if (!json.containsKey("refresh_token")) json["refresh_token"] = token.refreshToken

      this.tokenRef.val = JsonAccessToken(json)
    }
    finally c.close
  }

  protected static Map readJson(Str str) { JsonInStream(str.in).readJson }

  private static File toFile(Obj obj)
  {
    if (obj is File) return obj
    if (obj is Buf)  return ((Buf)obj).toFile(`chunk`)
    if (obj is Map)  return JsonOutStream.writeJsonToStr(obj).toBuf.toFile(`req.json`)
    throw ArgErr("Cannot convert to file ${obj.typeof}: ${obj}")
  }
}

