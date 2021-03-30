//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Aug 2009  Brian Frank  Creation
//   28 Apr 2016  Brian Frank  Port to 3.0
//

using web

**
** Foloi2Scheme implements client side legacy 2.1 authentication
**
const class Folio2Scheme : AuthScheme
{
  new make() : super("folio2") {}

  override AuthMsg onServer(AuthServerContext cx, AuthMsg msg)
  {
    throw UnsupportedErr()
  }

  override AuthMsg onClient(AuthClientContext cx, AuthMsg msg)
  {
    throw UnsupportedErr()
  }

  override Bool onClientNonStd(AuthClientContext cx, WebClient c, Str? content)
  {
    header := c.resHeaders["Folio-Auth-Api-Uri"]
    if (header == null) return false

    authUri  := toAuthUri(cx, header)
    authInfo := readAuthInfo(cx, authUri)
    digest   := computeDigest(cx, authInfo)
    cookie   := authenticate(cx, authUri, authInfo, digest)

    cx.headers["Cookie"] = cookie
    return true
  }

  private Uri toAuthUri(AuthClientContext cx, Str header)
  {
    cx.uri + header.toUri + `?${cx.user}`
  }

  private Str:Str readAuthInfo(AuthClientContext cx, Uri authUri)
  {
    c := cx.prepare(WebClient(authUri))
    response := cx.get(c)
    return parseAuthProps(response)
  }

  private Str computeDigest(AuthClientContext cx, Str:Str authInfo)
  {
    user  := cx.user
    pass  := cx.pass
    nonce := authInfo["nonce"] ?: throw cx.err("Missing 'nonce' in auth info")
    salt  := authInfo["userSalt"] ?: throw cx.err("Missing 'userSalt' in auth info")

    // compute salted hmac
    hmac := Buf().print("$user:$salt").hmac("SHA-1", pass.toBuf).toBase64

    // now compute login digest using nonce
    return "${hmac}:${nonce}".toBuf.toDigest("SHA-1").toBase64
  }

  private Str authenticate(AuthClientContext cx, Uri authUri, Str:Str authInfo, Str digest)
  {
    // post back to auth URI
    c := cx.prepare(WebClient(authUri))
    nonce := authInfo["nonce"]
    req := "nonce:$nonce\ndigest:$digest\n"
    if (authInfo["onAuthEnabled"] == "true") req += "password:$cx.pass\n"
    response := cx.post(c, req)

    if (c.resCode != 200) throw cx.err("Authentication failed")

    info := parseAuthProps(response)
    return info["cookie"] ?: throw cx.err("Missing 'cookie'")
  }

  private Str:Str parseAuthProps(Str text)
  {
    map := Str:Str[:]
    text.splitLines.each |line|
    {
      line = line.trim
      if (line.isEmpty) return
      colon := line.index(":")
      map[line[0..<colon].trim] = line[colon+1..-1].trim
    }
    return map
  }
}