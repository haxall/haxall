//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Apr 16  Brian Frank  Creation
//

using concurrent
using web

**
** Auth utilities
**
@NoDoc
const class AuthUtil
{

//////////////////////////////////////////////////////////////////////////
// Misc
//////////////////////////////////////////////////////////////////////////

  ** Encode a Str or Buf to base64uri format
  static Str toBase64(Obj x)
  {
    if (x is Str) x = ((Str)x).toBuf
    return ((Buf)x).toBase64Uri
  }

  ** Decode a base64Uri encoded string
  static Str fromBase64(Str s)
  {
    Buf.fromBase64(s).readAllStr
  }

//////////////////////////////////////////////////////////////////////////
// Salt
//////////////////////////////////////////////////////////////////////////

  ** Generate 32-byte cryptographic salt as base64 encoded string.
  static Str genSalt()
  {
    toBase64(Buf.random(32))
  }

  ** Generate 32-byte "fake" salt that looks consistent for given username
  static Str dummySalt(Str username)
  {
    toBase64("$username:$dummyRand".toBuf.toDigest("SHA-256"))
  }
  private static const Str dummyRand := Buf.random(16).toHex

//////////////////////////////////////////////////////////////////////////
// Nonce
//////////////////////////////////////////////////////////////////////////

  ** Nonce random mask for this VM
  static const Int nonceMask := Int.random

  ** Generate a nonce to use for digest.
  static Str genNonce()
  {
    rand  := Int.random
    ticks := DateTime.nowTicks.xor(nonceMask).xor(rand)
    return rand.toHex(16) + ticks.toHex(16)
  }

  ** Verify nonce submitted is fresh
  static Bool verifyNonce(Str nonce)
  {
    rand  := nonce[0..15].toInt(16)
    ticks := nonce[16..-1].toInt(16).xor(nonceMask).xor(rand)
    diff := (DateTime.nowTicks - ticks).abs
    return diff < 30sec.ticks
  }

//////////////////////////////////////////////////////////////////////////
// Req
//////////////////////////////////////////////////////////////////////////

  ** Return the given request's Authorization bearer token or null
  static Str? authToken(WebReq req)
  {
    header := req.headers["Authorization"]
    if (header == null) return null

    reqMsg := AuthMsg.fromStr(header, false)
    if (reqMsg == null) return null

    if (reqMsg.scheme != "bearer") return null

    return reqMsg.param("authToken", false)
  }

  ** Get the "real" remote address for a web request.
  **
  ** 1. Check the request headers for 'X-Real-IP'. This is the convention
  ** that NGINX uses for passing through the remote address.
  ** 2. Fallback to the 'req.remoteAddr'
  static Str realIp(WebReq req)
  {
     req.headers["X-Real-IP"] ?: req.remoteAddr.numeric
  }
}