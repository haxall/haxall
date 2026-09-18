//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 May 20  Matthew Giannini  Creation
//   27 Jan 22  Matthew Giannini  Port to Haxall
//

using concurrent
using web

**
** Implement the Authorization Code grant type
**
const class AuthCodeGrant
{
  ** Configure the authorization code grant with an [Authorization Request](AuthReq)
  ** and a [Token Request](AuthCodeTokenReq).
  new make(AuthReq authReq, AuthCodeTokenReq tokenReq)
  {
    this.authReq  = authReq
    this.tokenReq = tokenReq
  }

  const AuthReq authReq

  const TokenReq tokenReq

  ** Run the Authorization Code grant flow to obtain an access token. PKCE is
  ** always applied to mitigate the authorization code interception attack.
  **
  ** See [RFC 7636](https://tools.ietf.org/html/rfc7636) for PKCE details.
  @NoDoc AccessToken run()
  {
    // 1. Do the authorization request
    pkce := Pkce.gen
    authRes := authReq.authorize(pkce.params)

    // 2. Send the authorization code to the token endpoint to obtain the access token.
    // Also forward redirect_uri when authorize() returns one (e.g. from an ephemeral
    // loopback port — the same URI must be sent to the token endpoint per RFC 6749 §4.1.3).
    tokenParams := Str:Str["code": authRes["code"], "code_verifier": pkce.codeVerifier]
    if (authRes.containsKey("redirect_uri"))
      tokenParams["redirect_uri"] = authRes["redirect_uri"]
    return tokenReq.grant(authReq, tokenParams)
  }

  ** Runs the OAuth flow to get an OAuthClient.
  OAuthClient client()
  {
    token  := this.run
    params := ["client_id": authReq.clientId].addAll(tokenReq.customParams)
    return OAuthClient(token, tokenReq.tokenUri, params)
  }
}
