//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 May 2021  Brian Frank  Creation
//

using concurrent
using web
using haystack
using auth
using axon
using folio
using hx

**
** Authenticated user session management
**
const class HxUserSessions
{
  new make(HxUserLib lib) { this.lib = lib }

  ** Parent library
  const HxUserLib lib

  ** Logger to use for session login/logout
  Log log() { lib.log }

  ** List active sessions
  HxUserSession[] list() { byKey.vals(HxUserSession#) }

  ** Lookup a session by its key
  HxUserSession? get(Str key, Bool checked := true)
  {
    s := byKey[key]
    if (s != null) return s
    if (checked) throw UnknownNameErr(key)
    return null
  }

  ** Open new session
  HxUserSession open(WebReq req, HxUser user)
  {
    log.info("Login: $user.username")
    key := HxUserSession.genKey("s-")
    attestKey := HxUserSession.genKey("a-")
    session := HxUserSession(req, key, attestKey, user)
    byKey.add(session.key, session)
    return session
  }

  ** Open cluster session
  HxUserSession openCluster(WebReq req, Str key, Str attestKey, HxUser user)
  {
    log.info("Login cluster: $user.username")
    session := HxUserSession(req, key, attestKey, user) { it.isCluster = true }
    byKey.add(session.key, session)
    return session
  }

  ** Close session
  Void close(HxUserSession session)
  {
    log.info("Logout: $session.user.username")
    byKey.remove(session.key)
  }

  ** Cleanup expired sessions
  Void onHouseKeeping()
  {
    lease := (lib.rec["sessionTimeout"] as Number)?.toDuration(false) ?: 1hr
    now := Duration.now
    list.each |session|
    {
      if (session.isExpired(lease, now)) close(session)
    }
  }

  private const ConcurrentMap byKey := ConcurrentMap()
}

**************************************************************************
** HxUserSession
**************************************************************************

**
** Authenticated user session
**
const class HxUserSession : HxSession
{
  ** Constructor
  internal new make(WebReq req, Str key, Str attestKey, HxUser user, |This|? f := null)
  {
    if (f != null) f(this)
    this.key = key
    this.attestKey = attestKey
    this.remoteAddr = toRemoteAddr(req)
    this.userAgent  = req.headers["User-Agent"] ?: ""
    this.userRef = AtomicRef(user)
  }

  ** Primary session key
  const override Str key := genKey("s-")

  ** Secondary attest key to provide addtional security for Cookie non-GET requests
  const override Str attestKey := genKey("a-")

  ** User account authenticated with this session
  override HxUser user() { userRef.val }
  private const AtomicRef userRef

  ** Remote address of client
  const Str remoteAddr

  ** User agent of client
  const Str userAgent

  ** Created timestamp
  const DateTime created := DateTime.now

  ** Is this a session tunnelled thru a cluster
  const Bool isCluster

  ** Ticks last time this session was "touched"
  Int touched() { touchedRef.val }
  private const AtomicInt touchedRef := AtomicInt(Duration.nowTicks)

  ** Touch this session to indicate usage and update user definition
  Void touch(HxUser user)
  {
    userRef.val = user
    touchedRef.val = Duration.nowTicks
  }

  ** Check if time between now and last touch exceeds lease time
  Bool isExpired(Duration lease, Duration now) { now.ticks - touched > lease.ticks }

  ** Return session key
  override Str toStr() { key }

  ** Get the best remote address to use for request
  private static Str toRemoteAddr(WebReq req)
  {
    node := req.stash["clusterNode"]
    if (node != null) return node.toStr
    addr := req.headers["X-Real-IP"]
    if (addr == null) addr = req.headers["X-Forwarded-For"]
    if (addr == null) addr = req.remoteAddr.toStr
    return addr
  }

  ** Util to generate a random key
  static Str genKey(Str prefix) { prefix + Buf.random(32).toBase64Uri + "-" + keyCounter.incrementAndGet.toHex }
  private static const AtomicInt keyCounter := AtomicInt()
}


