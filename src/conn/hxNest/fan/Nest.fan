//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2022  Matthew Giannini  Creation
//

using oauth2

**
** Google Nest (SDM) Client (v1)
**
const class Nest
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(Str projectId, Str clientId, Str clientSecret, Str refreshToken, Log log := Log.get("nest"))
  {
    this.projectId = projectId
    token  := RawAccessToken("ForceRefreshAuthToken") { it.refreshToken = refreshToken }
    params := ["client_id": clientId, "client_secret": clientSecret]
    this.client = OAuthClient(token, tokenUri, params)
    this.log = log
  }

  ** Token refresh uri
  private static const Uri tokenUri := `https://www.googleapis.com/oauth2/v4/token`

  ** Project Id
  internal const Str projectId

  ** OAuth webclient
  internal const OAuthClient client

  ** Log
  const Log log

//////////////////////////////////////////////////////////////////////////
// API
//////////////////////////////////////////////////////////////////////////

  ** Get a structures endpoint
  StructuresReq structures() { StructuresReq(this) }

  ** Get a room endpoint
  RoomsReq rooms() { RoomsReq(this) }

  ** Get a devices endpoint
  DevicesReq devices() { DevicesReq(this) }

}