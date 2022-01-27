//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Mar 2020  Matthew Giannini  Creation
//   27 Jan 2022  Matthew Giannini  Port to Haxall
//

using util

**
** An OAuth2 access token
**
const mixin AccessToken
{
  ** The access token type (e.g. "Bearer")
  abstract Str tokenType()

  ** The acces token
  abstract Str accessToken()

  ** Get the refresh token if one is present
  abstract Str? refreshToken()

  ** Return true if the token includes a refresh token
  Bool hasRefreshToken() { refreshToken != null }

  ** How long until the token expires (if specified by the server)
  abstract Duration? expiresIn()

  ** The scopes for the token
  abstract Str[] scope()
}

**
** JSON Access Token (RFC 6749 §5.1)
**
const class JsonAccessToken : AccessToken
{
  static new fromStr(Str json)
  {
    JsonAccessToken((Map)JsonInStream(json.in).readJson)
  }

  new make(Str:Obj? json)
  {
    this.json = json
  }

  const Str:Obj? json

  override Str tokenType() { json.getChecked("token_type") }

  override Str accessToken() { json.getChecked("access_token") }

  override Str? refreshToken() { json["refresh_token"] }

  override Duration? expiresIn()
  {
    dur := json["expires_in"]
    if (dur == null) return null
    return Duration.fromStr("${dur}sec")
  }

  override Str[] scope()
  {
    (json["scope"] as Str)?.split(' ') ?: Str#.emptyList
  }

  override Str toStr() { json.toStr }
}

**
** Raw Access Token - Allows you to construct an access token explicitly
** and set all fields.
**
const class RawAccessToken : AccessToken
{
  new make(Str accessToken, |This|? f := null)
  {
    f?.call(this)
    this.accessToken = accessToken
  }

  override const Str tokenType := "Bearer"

  override const Str accessToken

  override const Str? refreshToken

  override const Duration? expiresIn

  override const Str[] scope := Str#.emptyList

  override Str toStr() { "{accessToken:$accessToken, refreshToken:$refreshToken, expiresIn:$expiresIn}" }
}