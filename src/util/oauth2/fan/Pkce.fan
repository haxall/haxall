//
// Copyright (c) 202
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 May 20  Matthew Giannini  Creation
//   27 Jan 22  Matthew Giannini  Port to Haxall
//
using util

**
** RFC 7636 implementation of Proof Key for Code Exchange
**
@NoDoc final const class Pkce
{
  private static const Str chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.~"
  private static const Int minLen := 43
  private static const Int maxLen := 128

  ** Generate a new Pkce instance with an auto-generated plain-code verifier
  static Pkce gen() { Pkce(genCode) }

  private new make(Str codeVerifier)
  {
    this.codeVerifier = codeVerifier
    this.challenge    = sha256(codeVerifier)
  }

  ** The plain code verifier
  const Str codeVerifier

  ** The hashed code verifier
  const Str challenge

  ** Get the URL params to for PKCE
  Str:Str params(Str:Str params := [:])
  {
    params["code_challenge"]        = challenge
    params["code_challenge_method"] = "S256"
    return params
  }

  ** Generate a plain code verifier
  static Str genCode()
  {
    rand := Random.makeSecure
    len  := rand.next(minLen..maxLen)
    buf  := StrBuf(len)
    len.times { buf.addChar(chars.get(rand.next(0..<chars.size))) }
    return buf.toStr
  }

  ** Get the Base64-URL encoding of the SHA-256 hash of the given str
  static Str sha256(Str str)
  {
    str.toBuf.toDigest("SHA-256").toBase64Uri
  }
}