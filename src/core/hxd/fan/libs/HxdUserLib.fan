//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using haystack
using auth
using folio

**
** User athentication and session management
**
const class HxdUserLib : HxdLib
{

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



