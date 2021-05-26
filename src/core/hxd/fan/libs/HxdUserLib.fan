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
const class HxdUserLib : HxdLib, HxRuntimeUsers
{
  override const HxdUserFuncs funcs := HxdUserFuncs(this)

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

  ** Construct a runtime specific context for the given user account
  override HxContext makeContext(HxUser user)
  {
    HxdContext(rt, user)
  }

  ** Authenticate a web request.  If request is for an unauthenticated
  ** user, then redirect to the login page and return null.
  override HxContext? authenticate(WebReq req, WebRes res)
  {
    null
  }

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

}

**************************************************************************
** HxdUserFuncs
**************************************************************************

const class HxdUserFuncs : HxLibFuncs
{
  new make(HxdUserLib lib) : super(lib) { this.lib = lib }

  const override HxdUserLib lib

  @Axon
  Str userTest() { "it works!" }
}


