//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Apr 2026  Brian Frank  Creation
//

**
** OAuth2Scheme implements the OAuth2 protocol
**
const class OAuth2Scheme : AuthScheme
{
  new make() : super("oauth2") {}

  **
  ** Challenge params whose values are base64url-encoded on the wire.
  ** Only these keys are decoded; all others are forwarded verbatim.
  **
  ** Server-side code that builds the OAUTH2 challenge (via AuthServerContext.extraChallenges)
  ** must encode exactly these params with AuthUtil.toBase64 and send all others as-is.
  **
  static const Str[] base64Params := [
    "issuer",
    "clientId",
    "scopes",
  ]

  **
  ** Selectively base64url-decode the params listed in `base64Params`;
  ** all other params are forwarded verbatim.
  **
  internal static Str:Str decodeParams(Str:Str raw)
  {
    raw.map |v, k->Str| { base64Params.contains(k) ? AuthUtil.fromBase64(v) : v }
  }

  override AuthMsg onClient(AuthClientContext cx, AuthMsg msg)
  {
    // can only use this in interactive mode
    if (!cx.interactive) throw AuthErr.makeUnsupportedScheme("Cannot use OAuth2 headless (use interactive opt)")

    // use reflection to call out to oauth loopback processing (avoids compile-time
    // dependency from auth → oauth2)
    bearer := Slot.findMethod("oauth2::OAuthClient.open").call(cx.uri, decodeParams(msg.params), cx.log)

    // bearer scheme short circuits the openStd loop
    return AuthMsg("bearer", ["authToken": bearer])
  }

  override AuthMsg onServer(AuthServerContext cx, AuthMsg msg)
  {
    throw AuthErr.makeUnsupportedScheme
  }

}

