//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using concurrent
using web
using xeto
using haystack
using auth
using axon
using folio
using hx
using hxm

**
** User athentication and session management
**
const class HxdUserExt : ExtObj, IUserExt
{
  ** Web servicing
  override const HxdUserWeb web := HxdUserWeb(this)

  ** Session management
  ISessionExt sessions() { sys.session }

  ** Settings record
  override HxdUserSettings settings() { super.settings }

  ** Disable auth for loopback and auto-login with superuser
  const Bool noAuth := sys.config.has("noAuth")

  ** URI for login page
  const Uri loginUri := web.uri + `login`

  ** URI to force logout
  const Uri logoutUri := web.uri + `logout`

  ** Session cookie name
  Str cookieName() { cookieNameRef.val }
  private const AtomicRef cookieNameRef := AtomicRef()

//////////////////////////////////////////////////////////////////////////
// HxdUserService
//////////////////////////////////////////////////////////////////////////

  ** Lookup a user by Ref id, Str username or Filter.  If not found
  ** then raise exception or return null based on the checked flag.
  override HxUser? read(Obj username, Bool checked := true)
  {
    Dict? rec
    if (username is Ref)
      rec = rt.db.readById(username, false)
    else if (username is Str)
      rec = rt.db.read(Filter.has("user").and(Filter.eq("username", username.toStr)), false)
    else if (username is Filter)
      rec = rt.db.read(Filter.has("user").and(username), false)
    else
      throw ArgErr("Invalid type for username [$username.typeof]")
    if (rec != null) return HxUser(rec)
    if (checked) throw UnknownRecErr("User not found: $username")
    return null
  }

  ** Authenticate a web request and return a context.  If request
  ** is not authenticated then redirect to login page and return null.
  override Context? authenticate(WebReq req, WebRes res, Runtime rt, Dict? opts := null)
  {
    // authenticate to get a session
    session := HxdUserAuth(this, req, res).authenticate
    if (session == null) return null

    // verify the user has access to the runtime
    user := session.user
    if (!user.access.canSeeProj(rt.meta)) return null

    // create a context and install it into current actor
    cx :=  rt.newContextSession(session)
    Actor.locals[ActorContext.actorLocalsKey] = cx

    return cx
  }

  ** Create synthetic user.  The tags arg may be a dict or a map.
  override HxUser makeUser(Str username, Obj? extra := null)
  {
    tags := Etc.dictToMap(Etc.makeDict(extra))
    tags["id"] = Ref(username)
    tags["username"] = username
    if (tags["userRole"] == null) tags["userRole"] = "admin"
    if (tags["mod"]      == null) tags["mod"]      = DateTime.nowUtc
    return HxUser(Etc.makeDict(tags))
  }

  ** Synthetic user for internal system processing
  override User syntheticUser(Str username)
  {
    HxUser(Etc.makeDict(["id":Ref(username), "username":username, "userRole":"op", "synthetic":Marker.val, "mod":DateTime.defVal]))
  }

  ** User database
  override const Folio db := sys.db

//////////////////////////////////////////////////////////////////////////
// Session
//////////////////////////////////////////////////////////////////////////

  ** Open a new session for given user account
  internal UserSession login(WebReq req, WebRes res, HxUser user)
  {
    log.info("Login: $user.username")
    session := sessions.open(user)
    addSessionCookie(req, res, session)
    return session
  }

  private Void addSessionCookie(WebReq req, WebRes res, UserSession session)
  {
    overrides := Field:Obj?[:]

    // we use enough built in security checks with the attest key
    // that we don't need to require the sameSite strict flag
    overrides[Cookie#sameSite] = null

    // if the public facing HTTP server is using HTTPS then force secure flag
    if (sys.http.siteUri.scheme == "https") overrides[Cookie#secure] = true

    // construct the session cookie
    cookie := Cookie.makeSession(cookieName, session.key, overrides)

    res.cookies.clear
    res.cookies.add(cookie)
  }

//////////////////////////////////////////////////////////////////////////
// Ext Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** Start callback - all libs are created and registered
  override Void onStart()
  {
    // set cookie name so its unique per http port
    http := sys.exts.getByType(IHttpExt#, false) as IHttpExt
    cookieNameRef.val = "hx-session-" + (http?.siteUri?.port ?: 80)

    // observer
    config := Etc.makeDict([
      "obsUpdates": Marker.val,
      "obsRemoves": Marker.val,
      "obsFilter": "user",
    ])
    observe("obsCommits", config, #onCommit)
  }

//////////////////////////////////////////////////////////////////////////
// Observations
//////////////////////////////////////////////////////////////////////////

  private Void onCommit(Dict msg)
  {
    subType := msg["subType"]
    if (subType == "updated")
    {
      newRec := msg["newRec"] as Dict
      user   := HxUser(newRec)
      if (user.isDisabled) closeAllSessionsForUser(user.id)
    }
    else if (subType == "removed")
    {
      oldRec := msg["oldRec"] as Dict
      user   := HxUser(oldRec)
      closeAllSessionsForUser(user.id)
    }
  }

  private Void closeAllSessionsForUser(Ref id)
  {
    userSessions(id).each |session| { sessions.close(session) }
  }

  private UserSession[] userSessions(Ref id)
  {
    sessions.list.findAll |session| { session.user.id == id }
  }
}

