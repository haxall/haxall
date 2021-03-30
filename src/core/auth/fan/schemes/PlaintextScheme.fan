//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 May 16  Matthew Giannini  Creation
//

**
** PlaintextScheme implements the x-plaintext algorithm for passing
** a username and password in the clear to the server for authentication.
**
const class PlaintextScheme : AuthScheme
{
  new make() : super("x-plaintext") {}

  override AuthMsg onClient(AuthClientContext cx, AuthMsg msg)
  {
    AuthMsg(name, [
      "username": AuthUtil.toBase64(cx.user),
      "password": AuthUtil.toBase64(cx.pass),
    ])
  }

  override AuthMsg onServer(AuthServerContext cx, AuthMsg msg)
  {
    // hello message
    if (msg.scheme == "hello") return AuthMsg(name)

    // authenticate
    given := AuthUtil.fromBase64(msg.param("password"))
    if (!cx.authSecret(given)) throw AuthErr("Invalid password")

    authToken := cx.login
    return AuthMsg(name, ["authToken": authToken])
  }
}