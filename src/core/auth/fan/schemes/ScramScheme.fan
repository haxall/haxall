//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Apr 16  Matthew Giannini  Creation
//

**
** ScramScheme implements the salted challenge response authentication
** mechanism as defined in [RFC 5802]`https://tools.ietf.org/html/rfc5802`.
**
const class ScramScheme : AuthScheme
{
  new make() : super("scram") {}

//////////////////////////////////////////////////////////////////////////
// Client
//////////////////////////////////////////////////////////////////////////

  override Void onClientSuccess(AuthClientContext cx, AuthMsg msg)
  {
    // decode server-final-message
    s2_msg := AuthUtil.fromBase64(msg.param("data"))
    data   := decodeMsg(s2_msg)

    // verify server signature
    if (cx.stash["serverSignature"] != data["v"])
      throw AuthErr("Invalid server signature")
  }

  override AuthMsg onClient(AuthClientContext cx, AuthMsg msg)
  {
    // generate next message to send to server
    msg.params["data"] == null
      ? sendClientFirstMessage(cx, msg)
      : sendClientFinalMessage(cx, msg)
  }

  private AuthMsg sendClientFirstMessage(AuthClientContext cx, AuthMsg msg)
  {
    // construct client-first-message
    c_nonce := Buf.random(clientNonceBytes).toHex
    c1_bare := "n=${cx.user},r=${c_nonce}"
    c1_msg  := gs2_header + c1_bare

    cx.log.debug("client-first-message: ${c1_msg}")

    params := ["data": AuthUtil.toBase64(c1_msg)]
    return AuthMsg(name, injectHandshakeToken(msg, params))
  }

  private AuthMsg sendClientFinalMessage(AuthClientContext cx, AuthMsg msg)
  {
    // decode server-first-message
    s1_msg := AuthUtil.fromBase64(msg.param("data"))
    data   := decodeMsg(s1_msg)

    // c2-no-proof
    cbind_input     := gs2_header
    channel_binding := AuthUtil.toBase64(cbind_input)
    nonce           := data["r"]
    c2_no_proof     := "c=${channel_binding},r=${nonce}"

    // proof
    hash       := msg.param("hash")
    salt       := data["s"]
    iterations := Int.fromStr(data["i"])
    scramKey   := ScramKey.compute(cx.pass, hash, salt, iterations)
    c_nonce    := nonce[0..<(clientNonceBytes*2)] // 2 chars per bytes for hex
    c1_bare    := "n=${cx.user},r=${c_nonce}"
    authMsg    := "${c1_bare},${s1_msg},${c2_no_proof}"
    clientSig  := authMsg.toBuf.hmac(hash, scramKey.storedKey)
    proof      := xor(scramKey.clientKey, clientSig).toBase64
    c2_msg     := "${c2_no_proof},p=${proof}"

    // compute server signature and stash for verification
    serverSig := authMsg.toBuf.hmac(hash, scramKey.serverKey).toBase64
    cx.stash["serverSignature"] = serverSig

    // debug
    cx.log.debug("auth-msg: ${authMsg}")
    cx.log.debug("client-final-message: ${c2_msg}")

    params := ["data": AuthUtil.toBase64(c2_msg)]
    return AuthMsg(name, injectHandshakeToken(msg, params))
  }

  private static const Int clientNonceBytes := 12
  private static const Str gs2_header := "n,,"

//////////////////////////////////////////////////////////////////////////
// Server
//////////////////////////////////////////////////////////////////////////

  override AuthMsg onServer(AuthServerContext cx, AuthMsg msg)
  {
    // hello message
    if (msg.scheme == "hello")
    {
      params := [
        "hash": cx.user.params["hash"],
        "handshakeToken": msg.param("username"),
      ]
      return AuthMsg(name, params)
    }

    // handshake message
    data := decodeMsg(AuthUtil.fromBase64(msg.param("data")))
    return data["p"] == null
      ? onClientFirstMessage(cx, msg)
      : onClientFinalMessage(cx, msg)
  }

  private AuthMsg onClientFirstMessage(AuthServerContext cx, AuthMsg msg)
  {
    // get user info
    user := cx.user
    hash := user.param("hash")
    salt := user.param("salt")
    i    := user.param("c")

    // salt is base64uri encoded. scram requires base64
    salt = Buf.fromBase64(salt).toBase64

    // decode client-first-message
    c1_msg := AuthUtil.fromBase64(msg.param("data"))
    data   := decodeMsg(c1_msg)

    // construct server-first-message
    c_nonce := data["r"]
    if (c_nonce == null || c_nonce.isEmpty)
      throw AuthErr("Bad client nonce: '${c_nonce}'")
    s_nonce := AuthUtil.genNonce
    nonce   := "${c_nonce}${s_nonce}"
    s1_msg  := "r=${nonce},s=${salt},i=${i}"

    if (cx.isDebug) cx.debug("server-first-message: ${s1_msg}")

    // build next challenge message
    params := ["hash": hash, "data": AuthUtil.toBase64(s1_msg)]
    return AuthMsg(name, injectHandshakeToken(msg, params))
  }

  private AuthMsg onClientFinalMessage(AuthServerContext cx, AuthMsg msg)
  {
    // get user info - VERY IMPORTANT - get username from handshakeToken
    // on order to support login by email instead of actual username
    user   := cx.user
    username := AuthUtil.fromBase64(msg.param("handshakeToken"))
    secret := cx.userSecret ?: throw AuthErr.makeUnknownUser(username)

    // auth params
    hash := user.param("hash")
    salt := user.param("salt")
    i    := user.param("c")

    // salt is base64uri encoded. scram requires base64
    salt = Buf.fromBase64(salt).toBase64

    // decode client-final-message
    c2_msg := AuthUtil.fromBase64(msg.param("data"))
    data   := decodeMsg(c2_msg)

    // extract and verify server nonce
    nonce   := data["r"]
    s_nonce := nonce[-(AuthUtil.genNonce.size)..-1]
    if (!AuthUtil.verifyNonce(s_nonce)) throw AuthErr("Invalid nonce")

    // reconstruct auth message
    c_nonce     := nonce[0..<(-s_nonce.size)]
    c1_bare     := "n=${username},r=${c_nonce}"
    s1_msg      := "r=${nonce},s=${salt},i=${i}"
    channel     := data["c"]
    c2_no_proof := "c=${channel},r=${nonce}"
    authMsg     := "${c1_bare},${s1_msg},${c2_no_proof}"

    // compute client signature
    saltedPassword := Buf.fromBase64(secret)
    scramKey  := ScramKey.gen(["hash": hash, "salt": Buf.fromBase64(salt), "iterations":"$i"])
    scramKey.saltedPassword = saltedPassword
    clientSig := authMsg.toBuf.hmac(hash, scramKey.storedKey)

    if (cx.isDebug)
    {
      cx.debug("auth-msg: ${authMsg}")
      cx.debug("saltedPassword=${saltedPassword.toBase64}")
      cx.debug("clientKey=${scramKey.clientKey.toBase64}")
      cx.debug("storedKey=${scramKey.storedKey.toBase64}")
      cx.debug("clientSig=${clientSig.toBase64}")
    }

    // recover client key
    proof     := Buf.fromBase64(data["p"])
    clientKey := xor(proof, clientSig)

    // verify
    computedSecret := clientKey.toDigest(hash)
    if (computedSecret.toBase64 != scramKey.storedKey.toBase64)
      throw AuthErr.makeInvalidPassword

    // compute server-final-message
    serverSig := authMsg.toBuf.hmac(hash, scramKey.serverKey)
    s2_msg := "v=${serverSig.toBase64}"

    params := ["authToken": cx.login, "hash": hash, "data": AuthUtil.toBase64(s2_msg)]
    return AuthMsg(name, params)
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  ** If the msg contains a handshake token, inject it into the given params
  private static Str:Str injectHandshakeToken(AuthMsg msg, Str:Str params)
  {
    tok := msg.params["handshakeToken"]
    if (tok != null) params["handshakeToken"] = tok
    return params
  }

  ** Decode raw scram message
  private static Str:Str decodeMsg(Str s)
  {
    data := Str:Str[:]
    s.split(',').each |tok|
    {
      n := tok.index("=")
      if (n == null) return
      data.add(tok[0..<n], tok[(n+1)..-1])
    }
    return data
  }

  private static Buf xor(Buf a, Buf b)
  {
    if (a.size != b.size) throw ArgErr("sizes don't match: ${a.size} <> ${b.size}")
    x := Buf()
    for (i := 0; i < a.size; ++i)
    {
      x.write(a.get(i).xor(b.get(i)))
    }
    return x
  }
}

**
** ScramKey is a javascript-friendly utility for working with scram configuration
** and secret generation.
**
@NoDoc @Js
class ScramKey
{
  ** Create a scram key generator with the given configuration
  **   - hash: (Str) the cryptographic hash function to use (e.g SHA-256)
  **   - salt: (Buf) the salt to use
  **   - c: (Int) the number of iterations to apply of the PRF.
  ** If any parameter is missing, a suitable default is used.
  static new gen(Str:Obj? config := [:])
  {
    hashFunc := config["hash"] ?: "SHA-256"
    salt     := config["salt"] ?: Buf.random(32)
    c        := config["c"]    ?: 10_000
    return ScramKey(hashFunc, salt, c)
  }

  ** Create a scram key generator from the configuration in the given auth msg
  static ScramKey fromAuthMsg(AuthMsg msg)
  {
    if (msg.scheme != "scram") throw ArgErr("Not a scram msg: ${msg}")
    return ScramKey.gen([
      "hash": msg.param("hash"),
      "salt": Buf.fromBase64(msg.param("salt")),
      "c": Int.fromStr(msg.param("c")),
    ])
  }

  ** Configure a scram key and then compute all components of the stored
  ** key and server key using the given password
  **   - password: the secret password
  **   - hash: the cryptographic hash function to use (e.g. SHA-256)
  **   - salt: (Str) the base64 encoded salt, or (Buf) containing raw salt.
  **   - c: the number of iterations to apply of the PRF
  static ScramKey compute(Str password, Str hash, Obj salt, Int c)
  {
    if (salt is Str) salt = Buf.fromBase64((Str)salt)
    else if (salt isnot Buf) throw ArgErr("salt must be base64 encoded Str, or Buf")
    key := ScramKey(hash, salt, c)
    key.toSecret(password)
    return key
  }

  private new make(Str hashFunc, Buf salt, Int c)
  {
    this.hashFunc = hashFunc
    this.salt     = salt
    this.c        = c
  }

  ** The scram hash function
  const Str hashFunc

  ** The scram salt
  Buf salt { private set }

  ** Number of iterations to run
  const Int c

  ** Get an `AuthMsg` representing the configuration for this key.
  AuthMsg toAuthMsg()
  {
    AuthMsg("scram", [
      "hash": hashFunc,
      "salt": salt.toBase64Uri,
      "c":    c.toStr,
    ])
  }

  ** clientKey, storedKey, and serverKey are only computed when this field
  ** is set.
  internal Buf? saltedPassword
  {
    set {
      &saltedPassword = it
      clientKey = Buf().writeChars("Client Key").hmac(hashFunc, &saltedPassword)
      storedKey = clientKey.toDigest(hashFunc)
      serverKey = Buf().writeChars("Server Key").hmac(hashFunc, &saltedPassword)
    }
  }
  internal Buf? clientKey  { private set}
  internal Buf? storedKey  { private set }
  internal Buf? serverKey  { private set }

  Str toSecret(Str password)
  {
    if (password.isEmpty) throw Err("Scram scheme password cannot be empty")

    pbk      := "PBKDF2WithHmac" + hashFunc.replace("-", "")
    keyBytes :=  keyBits(hashFunc) / 8

    // set internal fields for computed key
    saltedPassword = Buf.pbk(pbk, password, salt, c, keyBytes)

    // return the salted password; this should be stored in password database
    return saltedPassword.toBase64Uri
  }

  ** Get generated key length in bits (not bytes) for the given hash function.
  static Int keyBits(Str hash)
  {
    switch (hash.upper)
    {
      case "SHA-1":   return 160
      case "SHA-256": return 256
      case "SHA-512": return 512
      default: throw ArgErr("Unsupported hash function: ${hash}")
    }
  }
}