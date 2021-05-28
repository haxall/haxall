//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

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

//////////////////////////////////////////////////////////////////////////
// HxRuntimeUsers
//////////////////////////////////////////////////////////////////////////

  ** Lookup a user by username.  If not found then raise
  ** exception or return null based on the checked flag.
  override HxUser? read(Obj username, Bool checked := true)
  {
    user := null
    if (checked) throw UnknownRecErr("User not found: $username")
    return null
  }

  ** Authenticate a web request.  If request is for an unauthenticated
  ** user, then redirect to the login page and return null.
  override HxContext? authenticate(WebReq req, WebRes res)
  {
     throw Err("TODO")
  }

//////////////////////////////////////////////////////////////////////////
// HxLib
//////////////////////////////////////////////////////////////////////////

  ** Run house keeping couple times a minute
  override Duration? houseKeepingFreq() { 17sec }

  ** Cleanup expired sessions
  override Void onHouseKeeping() { sessions.onHouseKeeping }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  static Void addUser(Folio db, Str user, Str pass, Str role)
  {
    scram := ScramKey.gen
    userAuth := authMsgToDict(scram.toAuthMsg)
    secret := scram.toSecret(pass)

    changes := [
      "username":user,
      "dis":user,
      "user":Marker.val,
      "userRole": role,
      "userAuth": userAuth,
      "created": DateTime.now,
      "tz": TimeZone.cur.toStr,
      "disabled": Remove.val,
    ]
    rec := db.commit(Diff.makeAdd(changes)).newRec
    db.passwords.set(rec.id.id, secret)
  }

  static Void updatePassword(Folio db, Dict rec, Str pass)
  {
    scram := ScramKey.gen
    userAuth := authMsgToDict(scram.toAuthMsg)
    secret := scram.toSecret(pass)

    changes := ["userAuth": userAuth]
    db.commit(Diff(rec, changes))
    db.passwords.set(rec.id.id, secret)
  }

  private static Dict authMsgToDict(AuthMsg msg)
  {
    userAuth := Str:Obj["scheme": msg.scheme]
    msg.params.each |v, k|
    {
     if ("c" == k) userAuth[k] = Number(Int.fromStr(v, 10))
     else userAuth[k] = v
    }
    return Etc.makeDict(userAuth)
  }

  internal static AuthMsg? dictToAuthMsg(Dict userAuth, Bool checked := true)
  {
    Str? scheme := null
    params := Str:Str[:]
    userAuth.each |v, k|
    {
      if ("scheme" == k) scheme = v
      else params[k] = "$v"
    }
    try
    {
      return AuthMsg(scheme, params)
    }
    catch (Err e)
    {
      if (checked) throw e
      return null
    }
  }

}

