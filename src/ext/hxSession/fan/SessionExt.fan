//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Jun 2026  Matthew Giannini  Creation
//

using concurrent
using util
using web
using auth
using xeto
using haystack
using hx

**
** User session management for Haxall
**
const class SessionExt : ExtObj, ISessionExt
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make()
  {
  }

  ** Lock to make session management atomic
  private const Lock sessionLock := Lock.makeReentrant

  ** Sessions mapped by Ref id
  private const ConcurrentMap byId := ConcurrentMap()

  ** Sessions mapped by session key
  private const ConcurrentMap byKey := ConcurrentMap()

  ** The number of sessions (Int) open for a user (keyed by username)
  private const ConcurrentMap userCounts := ConcurrentMap()

//////////////////////////////////////////////////////////////////////////
// Ext
//////////////////////////////////////////////////////////////////////////

  override SessionSettings settings() { super.settings }

  override Duration? houseKeepingFreq() { 17sec }

  override Void onHouseKeeping()
  {
    now := Duration.now
    list.each |session|
    {
      // close expired sessions
      if (session.isExpired(now)) close(session)
    }
  }

//////////////////////////////////////////////////////////////////////////
// SessionExt
//////////////////////////////////////////////////////////////////////////

  ** Get the configured lease time for this session or return the default
  protected virtual Duration lease(ServerSession session, Duration def := 3hr)
  {
    if (session.isWeb) return settings.webSessionTimeout
    return def
  }

//////////////////////////////////////////////////////////////////////////
// ISessionExt
//////////////////////////////////////////////////////////////////////////

  override ServerSession open(User user, Dict? meta := null)
  {
    req   := Actor.locals["web.req"] as WebReq
    acc   := Etc.dictToMap(meta)
    if (req != null)
    {
      injectWebMeta(req, acc)
      injectClusterMeta(req, acc)
    }

    // auto-generate key and attest key if they are missing
    if (acc["id"] as Ref == null) acc["id"] = Ref.gen
    if (acc["key"] == null) acc["key"] = genKey("web-")
    if (acc["attestKey"] == null) acc["attestKey"] = genKey("a-")

    // hook to create a session based on the current meta
    session := createSession(user, acc)

    // open and register the session
    return doOpen(session)
  }

  private Void injectWebMeta(WebReq req, Str:Obj? meta)
  {
    meta["web"] = Marker.val
    meta["remoteAddr"] = toRemoteAddr(req)
    meta["userAgent"] = req.headers["User-Agent"]
  }

  private Void injectClusterMeta(WebReq req, Str:Obj? meta)
  {
    key := req.stash["clusterSessionKey"] as Str
    if (key == null) return
    meta["cluster"] = Marker.val
    meta["key"] = key
    meta["attestKey"] = (req.stash["clusterAttestKey"] as Str) ?: throw AuthErr("Missing cluster attest key")
  }

  ** Callback to create a user session instance.
  protected virtual ServerSession createSession(User user, Str:Obj? meta)
  {
    ServerSession(this, user, Etc.makeDict(meta))
  }

  ** Chokepoint for registering a newly opened session.
  protected ServerSession doOpen(ServerSession session)
  {
    username := session.username

    return sessionLock.withLock |->Obj?| {
      // check session limits
      if (!session.user.isSu)
      {
        // user limit
        if (userCount(username) >= settings.maxSessionsPerUser)
          throw MaxSessionsErr("Max sessions exceeded for user: ${username}")

        // system limit
        if (byKey.size >= settings.maxSessions)
          throw MaxSessionsErr("Max total sessions exceeded")
      }

      // register the session
      try
      {
        userCounts.set(username, userCount(username)+1)
        byId.add(session.id, session)
        byKey.add(session.key, session)
      }
      catch (Err err)
      {
        close(session)
        throw err
      }
      return session
    }
  }

  override ServerSession? get(Str key, Bool checked := true)
  {
    s := byKey.get(key)
    if (s != null) return s
    if (checked) throw UnknownNameErr(key)
    return null
  }

  ServerSession? getById(Ref id, Bool checked := true)
  {
    s := byId.get(id)
    if (s != null) return s
    if (checked) throw UnknownNameErr("$id")
    return null
  }

  override ServerSession[] list() { byKey.vals(ServerSession#) }

  override Int size() { byKey.size }

  override Void close(UserSession session)
  {
    username := session.username
    sessionLock.withLock |->Obj?| {
      byId.remove(session.id)
      byKey.remove(session.key)
      userCounts.set(username, userCount(username)-1)
      return null
    }
  }

//////////////////////////////////////////////////////////////////////////
// Func Support
//////////////////////////////////////////////////////////////////////////

  ** Get a grid with details about all opened sessions
  virtual Grid toGrid()
  {
    gb := GridBuilder()
    gb.addCol("id", ["hidden":Marker.val])
    gridCols.each { gb.addCol(it) }
    gb.addCol("mod", ["hidden":Marker.val])
    list.each |session| { gb.addDictRow(Etc.makeDict(toGridRow(session))) }
    return gb.toGrid
  }

  protected virtual Str[] gridCols()
  {
    ["key", /*"type",*/ "username", "userDis", "userAgent", "remoteAddr", "created", "lease", "touched"]
  }

  protected virtual Str:Obj? toGridRow(ServerSession session)
  {
    [
      "id": session.id,
      "key": session.key[0..8] + "...",
      // "type": session.isWeb ? "web" : "unknown",
      "username": session.username,
      "userDis": session.user.dis,
      "userAgent": session.userAgent,
      "remoteAddr": session.remoteAddr,
      "created": session.created,
      "lease": Number(session.lease),
      "touched": Number(Duration(Duration.nowTicks-session.touched)),
      "mod": DateTime.defVal,
    ]
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  ** Get the number of sessions opened with this username
  Int userCount(Str username) { userCounts.get(username) ?: 0 }

  ** Iterate user count map
  Void userCountEach(|Str username, Int count| f)
  {
    userCounts.each |Int i, Str u| { f(u, i) }
  }

  static Str toRemoteAddr(WebReq req)
  {
    node := req.stash["clusterNode"]
    if (node != null) return node.toStr
    addr := req.headers["X-Real-IP"]
    if (addr == null) addr = req.headers["X-Forwarded-For"]
    if (addr == null) addr = req.remoteAddr.toStr
    return addr
  }

  ** Util to generate a random key
  static Str genKey(Str prefix) { prefix + Buf.random(32).toBase64Uri + "-" + keyCounter.incrementAndGet }
  private static const AtomicInt keyCounter := AtomicInt()
}

**************************************************************************
** Settings
**************************************************************************

@NoDoc
const class SessionSettings : Settings
{
  ** Constructor
  new make(Dict d, |This| f) : super(d) { f(this) }

  ** Web session lease timeout (cookie and HTTP API logins).  A new web
  ** session is created each time a user logins in through the HTTP
  ** authentication protocol.  The client may use a cookie or auth token to
  ** identify the session on subsequent HTTP requests.
  @Setting
  const Duration webSessionTimeout := 3hr

  ** Maximum number of all non-superuser sessions.  Super users can
  ** always create new sessions beyond this threshold.  After this limit
  ** is reached any attempt to login a new non-superuser session will
  ** return a HTTP 503 error.
  @Setting
  const Int maxSessions := 2500

  ** Maximum number of sessions for a single user account (both web and ui).
  ** Super users can always create new sessions beyond this threshold.
  ** After this limit is reached any attempt to login with a specific
  ** user account will return a HTTP 503 error.
  @Setting
  const Int maxSessionsPerUser := 500

  // ** How long before a session will timeout. This usually applies to an
  // ** inactive web session, but for token-based sessions this may be used
  // ** to indicate how often to refresh the token.
  // @Setting
  // const Duration sessionTimeout := 1hr
}
