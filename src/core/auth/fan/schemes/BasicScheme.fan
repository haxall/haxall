//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Apr 2016  Brian Frank  Creation
//

using web

**
** BasicScheme
**
const class BasicScheme : AuthScheme
{
  new make() : super("basic") {}

  override AuthMsg onServer(AuthServerContext cx, AuthMsg msg)
  {
    throw UnsupportedErr()
  }

  override AuthMsg onClient(AuthClientContext cx, AuthMsg msg)
  {
    throw UnsupportedErr()
  }

  static Bool use(WebClient c, Str? content)
  {
    resCode   := c.resCode
    wwwAuth   := c.resHeaders.get("WWW-Authenticate", "").lower
    server    := c.resHeaders.get("Server", "").lower
    setCookie := c.resHeaders.get("Set-Cookie", "").lower

    // standard basic challenge
    if (resCode == 401 && wwwAuth.startsWith("basic")) return true

    // fallback to basic if server says its Niagara
    if (server.startsWith("niagara") || setCookie.contains("niagara")) return true

    // this is a N4 bug from our hello message to tell us we are talking to Niagara
    if (resCode == 500 && content != null && content.contains("wrong 4-byte ending")) return true

    return false
  }

  override Bool onClientNonStd(AuthClientContext cx, WebClient c, Str? content)
  {
    if (!use(c, content)) return false

    cred := "$cx.user:$cx.pass".toBuf.toBase64
    headerKey := "Authorization"
    headerVal := "Basic $cred"

    // make request another request to verify
    c = cx.prepare(WebClient(cx.uri))
    c.reqHeaders[headerKey] = headerVal
    cx.get(c)
    if (c.resCode != 200) throw cx.err("Basic auth failed: $c.resCode $c.resPhrase")

    // pass Authorization headers for future requests
    cx.headers[headerKey] = headerVal
    return true
  }
}