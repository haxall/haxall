//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   02 Feb 2022  Matthew Giannini  Creation
//

using oauth2

**
** Ecobee client
**
const class Ecobee
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(Str clientId, Str refreshToken, Log log := Log.get("ecobee"))
  {
    token  := RawAccessToken("ForceRefreshAuthToken") { it.refreshToken = refreshToken }
    params := ["client_id": clientId]
    this.client = OAuthClient(token, tokenUri, params)
    this.log = log
  }

  ** Token refresh uri
  private static const Uri tokenUri := `https://api.ecobee.com/token`

  ** OAuth webclient
  internal const OAuthClient client

  internal const Log log

//////////////////////////////////////////////////////////////////////////
// API
//////////////////////////////////////////////////////////////////////////

  ** Get the thermostat api endpoint
  ThermostatReq thermostat() { ThermostatReq(this) }
}