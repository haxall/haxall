//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using concurrent
using web
using haystack
using auth
using axon
using folio
using hx

**
** User athentication and session management
**
const class HxUserLib : HxLib, HxRuntimeUsers
{
  ** Web servicing
  override const HxUserWeb web := HxUserWeb(this)

  ** Axon functions
  override const HxUserFuncs funcs := HxUserFuncs(this)

  ** Session management
  const HxUserSessions sessions := HxUserSessions(this)

  ** URI for login page
  const Uri loginUri := web.uri + `login`

  ** URI to force logout
  const Uri logoutUri := web.uri + `logout`

  ** Session cookie name
  Str cookieName() { cookieNameRef.val }
  private const AtomicRef cookieNameRef := AtomicRef()

//////////////////////////////////////////////////////////////////////////
// HxRuntimeUsers
//////////////////////////////////////////////////////////////////////////

  ** Lookup a user by username.  If not found then raise
  ** exception or return null based on the checked flag.
  override HxUser? read(Obj username, Bool checked := true)
  {
    rec := username is Ref ?
           rt.db.readById(username, false) :
           rt.db.read("username==$username.toStr.toCode", false)
    if (rec != null) return HxUserImpl(rec)
    if (checked) throw UnknownRecErr("User not found: $username")
    return null
  }

  ** Authenticate a web request and return a context.  If request
  ** is not authenticated then redirect to login page and return null.
  override HxContext? authenticate(WebReq req, WebRes res)
  {
    HxUserAuth(this, req, res).authenticate
  }

//////////////////////////////////////////////////////////////////////////
// HxLib Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** Start callback - all libs are created and registered
  override Void onStart()
  {
    // set cookie name so its unique per http port
    cookieNameRef.val = "hx-session-" + (rt.httpUri.port ?: 80)
  }

  ** Run house keeping couple times a minute
  override Duration? houseKeepingFreq() { 17sec }

  ** Cleanup expired sessions
  override Void onHouseKeeping() { sessions.onHouseKeeping }

}

