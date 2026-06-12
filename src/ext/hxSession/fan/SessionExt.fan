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

  ** Map of all open sessions
  internal const SessionMap sessionMap := SessionMap()

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

  final override ServerSession open(User user, Dict? meta := null)
  {
    req   := Actor.locals["web.req"] as WebReq
    acc   := Etc.dictToMap(meta)

    // only internal implementation may set keys, so remove them if they
    // were passed in. do not treat this as an error right now
    acc.remove("key")
    acc.remove("attestKey")

    // web meta
    if (req != null)
    {
      injectWebMeta(req, acc)
      injectClusterMeta(req, acc)
    }

    // auto-generate key and attest key if they are missing
    key := acc.remove("key") ?: genKey("web-")
    attestKey := acc.remove("attestKey") ?: genKey("a-")

    // create and register the session
    session := register(createSession(user, key, attestKey, acc))

    // sub-class hook
    onOpen(session)

    return session
  }

  ** Callback after a session is opened and registered.
  protected virtual Void onOpen(ServerSession session) { }

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
  protected virtual ServerSession createSession(User user, Str key, Str attestKey, Str:Obj? meta)
  {
    ServerSession(this, user, key, attestKey, Etc.makeDict(meta))
  }

  ** Chokepoint for registering a newly opened session.
  private ServerSession register(ServerSession session)
  {
    username := session.username

    // check session limits
    if (!session.user.isSu)
    {
      // user limit
      if (sessionMap.userCount(username) >= settings.maxSessionsPerUser)
        throw MaxSessionsErr("Max sessions exceeded for user: ${username}")

      // system limit
      if (this.size >= settings.maxSessions)
        throw MaxSessionsErr("Max total sessions exceeded")
    }

    // register the session
    sessionMap.add(session)

    return session
  }

  override ServerSession? get(Str key, Bool checked := true) { sessionMap.get(key, checked) }

  ** Get a session by its id.
  ServerSession? getById(Ref id, Bool checked := true) { sessionMap.getById(id, checked) }

  ** Get the number of sessions opened for thie given username
  Int userCount(Str username) { sessionMap.userCount(username) }

  override ServerSession[] list() { sessionMap.list }

  override Int size() { sessionMap.size }

  final override Void close(UserSession session)
  {
    sessionMap.remove(session)
    onClose(session)
  }

  ** Callback when a session is closed. The session will already be unmapped
  ** when this is called
  protected virtual Void onClose(UserSession session) { }

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
