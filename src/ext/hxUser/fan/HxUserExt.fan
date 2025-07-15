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
const class HxUserExt : ExtObj, IUserExt
{
  ** Web servicing
  override const HxUserWeb web := HxUserWeb(this)

  ** Session management
  const HxUserSessions sessions := HxUserSessions(this)

  ** Settings record
  override HxUserSettings rec() { super.rec }

  ** Auto login a configured superuser account for testing
  const Bool noAuth := sys.config.has("noAuth")

  ** URI for login page
  const Uri loginUri := web.uri + `login`

  ** URI to force logout
  const Uri logoutUri := web.uri + `logout`

  ** Session cookie name
  Str cookieName() { cookieNameRef.val }
  private const AtomicRef cookieNameRef := AtomicRef()

//////////////////////////////////////////////////////////////////////////
// HxUserService
//////////////////////////////////////////////////////////////////////////

  ** Lookup a user by username.  If not found then raise
  ** exception or return null based on the checked flag.
  override HxUser? read(Obj username, Bool checked := true)
  {
    rec := username is Ref ?
           proj.db.readById(username, false) :
           proj.db.read(Filter.eq("username", username.toStr).and(Filter.has("user")), false)
    if (rec != null) return HxUser(rec)
    if (checked) throw UnknownRecErr("User not found: $username")
    return null
  }

  ** Authenticate a web request and return a context.  If request
  ** is not authenticated then redirect to login page and return null.
  override UserSession? authenticate(WebReq req, WebRes res)
  {
    HxUserAuth(this, req, res).authenticate
  }

  ** Close the given authentication session
  override Void closeSession(UserSession session)
  {
    sessions.close(session)
  }

  ** Create synthetic user.  The tags arg may be a dict or a map.
  override HxUser makeSyntheticUser(Str username, Obj? extra := null)
  {
    extraTags := Etc.makeDict(extra)
    tags := ["id": Ref(username), "username":username, "userRole":"admin", "mod":DateTime.nowUtc, "synthetic":Marker.val]
    extraTags.each |v, n| { tags[n] = v }
    return HxUser(Etc.makeDict(tags))
  }

  ** Configured max sessions
  override Int maxSessions() { rec.maxSessions }

//////////////////////////////////////////////////////////////////////////
// Session
//////////////////////////////////////////////////////////////////////////

  ** Open a new session for given user account
  internal HxUserSession login(WebReq req, WebRes res, HxUser user)
  {
    session := sessions.open(req, user)
    addSessionCookie(req, res, session)
    return session
  }

  private Void addSessionCookie(WebReq req, WebRes res, HxUserSession session)
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
    cookieNameRef.val = "hx-session-" + (sys.http.siteUri.port ?: 80)
  }

  ** Run house keeping couple times a minute
  override Duration? houseKeepingFreq() { 17sec }

  ** Cleanup expired sessions
  override Void onHouseKeeping()
  {
    lease := (rec["sessionTimeout"] as Number)?.toDuration(false) ?: 1hr
    sessions.onHouseKeeping(lease)
  }

}

