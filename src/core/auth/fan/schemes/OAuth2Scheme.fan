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

  override AuthMsg onClient(AuthClientContext cx, AuthMsg msg)
  {
    // can only use this in interactive mode
    if (!cx.interactive) throw AuthErr.makeUnsupportedScheme("Cannot use OAuth2 headless (use interactive opt)")

    // use reflection to call out to oauth loopback processing
    bearer := Slot.findMethod("oauth2::OAuthClient.open").call(cx.uri, msg.params, cx.log)

    // bearer scheme short circuits the openStd loop
    return AuthMsg("bearer", ["authToken": bearer])
  }

  override AuthMsg onServer(AuthServerContext cx, AuthMsg msg)
  {
    throw AuthErr.makeUnsupportedScheme
  }

}

