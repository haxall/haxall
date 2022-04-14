//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Apr 16  Brian Frank  Creation
//

**
** HmacScheme implements pre-3.0 HMAC SHA-1 algorithm
**
const class HmacScheme : AuthScheme
{
  static Str:Str gen()
  {
    ["hash":"SHA-1",
     "salt":AuthUtil.genSalt]
  }


  new make() : super("hmac") {}

  override AuthMsg onClient(AuthClientContext cx, AuthMsg msg)
  {
    // gather request parameters - salt must be converted to "normal" baes64
    user  := cx.user
    pass  := cx.pass
    hash  := msg.param("hash")
    salt  := Buf.fromBase64(msg.param("salt")).toBase64
    nonce := msg.param("nonce")

    // compute secret and then digest of that
    secret := hmac(user, pass, salt, hash)
    digest := "$secret:$nonce".toBuf.toDigest(hash)

    // return message to send back to server
    return AuthMsg(name, [
        "handshakeToken": AuthUtil.toBase64(cx.user),
        "digest": AuthUtil.toBase64(digest),
        "nonce": nonce,
      ])
  }

  override AuthMsg onServer(AuthServerContext cx, AuthMsg msg)
  {
    // hello message
    if (msg.scheme == "hello")
    {
      params := cx.user.params.dup
      params["nonce"] = AuthUtil.genNonce
      return AuthMsg(name, params)
    }

    // verify
    user     := cx.user.username
    secret   := cx.userSecret
    hash     := cx.user.param("hash")
    nonce    := msg.param("nonce")
    digest   := msg.param("digest")
    expected := AuthUtil.toBase64("$secret:$nonce".toBuf.toDigest(hash))


    // debug
    if (cx.isDebug)
    {
      cx.debug("hmac.nonce:    $nonce")
      cx.debug("hmac.digest:   $digest")
      cx.debug("hmac.expected: $expected")
    }

    if (expected != digest) throw AuthErr.makeInvalidPassword

    authToken := cx.login
    return AuthMsg("hmac", ["authToken":authToken])
  }

  ** Compute the secret string which is *normal* base64
  ** HMAC of the "user:salt" like we used in 2.1
  static Str hmac(Str user, Str pass, Str salt, Str hash := "SHA-1")
  {
    // salt must be converted to normal base64
    salt = Buf.fromBase64(salt).toBase64
    return "$user:$salt".toBuf.hmac(hash, pass.toBuf).toBase64
  }

}


