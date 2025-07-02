//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 May 2021  Brian Frank  Creation
//

using web
using xeto
using haystack
using auth
using folio
using hx

**
** User library utilities
**
const class HxUserUtil
{
  ** Add a new user record and its password hash to database
  static HxUser addUser(Folio db, Str user, Str pass, Str:Obj tags)
  {
    scram := ScramKey.gen
    userAuth := authMsgToDict(scram.toAuthMsg)
    secret := scram.toSecret(pass)

    tags = tags.dup
    tags["username"] = user
    tags["user" ]    = Marker.val
    tags["created"]  = DateTime.now
    tags["userAuth"] = userAuth
    tags["disabled"] = Remove.val
    addUserSet(tags, "dis",      user)
    addUserSet(tags, "tz",       TimeZone.cur.toStr)
    addUserSet(tags, "userRole", "op")

    rec := db.commit(Diff.makeAdd(tags)).newRec
    db.passwords.set(rec.id.id, secret)

    return HxUserImpl(rec)
  }

  ** Set given name/val pair if not already defined
  private static Void addUserSet(Str:Obj tags, Str name, Str val)
  {
    if (tags[name] == null) tags[name] = val
  }

  ** Update the password hash in the database
  static Void updatePassword(Folio db, Dict rec, Str pass)
  {
    scram := ScramKey.gen
    userAuth := authMsgToDict(scram.toAuthMsg)
    secret := scram.toSecret(pass)

    changes := ["userAuth": userAuth]
    db.commit(Diff(rec, changes))
    db.passwords.set(rec.id.id, secret)
  }

  ** Convert parameters message to 'userAuth' Dict
  static Dict authMsgToDict(AuthMsg msg)
  {
    userAuth := Str:Obj["scheme": msg.scheme]
    msg.params.each |v, k|
    {
     if ("c" == k) userAuth[k] = Number(Int.fromStr(v, 10))
     else userAuth[k] = v
    }
    return Etc.makeDict(userAuth)
  }

  ** Convert 'userAuth' Dict to parameters message
  static AuthMsg? dictToAuthMsg(Dict userAuth, Bool checked := true)
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

