//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 May 20  Matthew Giannini  Creation
//   27 Jan 22  Matthew Giannini  Port to Haxall
//

using web
using util

**
** Base class for all Token Requests
**
abstract const class TokenReq
{
  ** Construct a TokenReq. The tokenUri is the endpoint for doing the token request.
  ** You may specify additional custom parameters that should be included in the token
  ** request also.
  new make(Uri tokenUri, [Str:Str] customParams := [:])
  {
    this.tokenUri     = tokenUri
    this.customParams = customParams
  }

  const Uri tokenUri

  const Str:Str customParams

  abstract Str grantType()

  virtual Str:Str build()
  {
    params := customParams.dup
    params["grant_type"] = grantType
    return params
  }

  abstract AccessToken grant(AuthReq authReq, Str:Str flowParams)
}

**************************************************************************
** AuthCodeTokenReq
**************************************************************************

**
** Token Request for the Authorization Code grant type.
**
const class AuthCodeTokenReq : TokenReq
{
  new make(Uri tokenUri, [Str:Str] customParams := [:]) : super(tokenUri, customParams)
  {
  }

  override const Str grantType := "authorization_code"

  override AccessToken grant(AuthReq req, Str:Str flowParams)
  {
    params := flowParams.dup.addAll(this.build)
    params["client_id"] = req.clientId
    if (req.redirectUri != null) params["redirect_uri"] = req.redirectUri.toStr

    client := WebClient(tokenUri).postForm(params)
    return JsonAccessToken(client.resStr)
  }
}

