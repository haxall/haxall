//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 May 2021  Brian Frank  Creation
//   13 Jul 2025  Brian Frank  Refactor from hxUser
//

using xeto
using haystack
using hx

**
** Haxall default implementation of User
**
const class HxUser : User
{
  new make(Dict meta)
  {
    this.meta     = meta
    this.id       = meta.id
    this.username = meta->username
    this.dis      = meta["dis"] ?: username
    this.email    = meta["email"] as Str
    this.mod      = meta->mod
    this.tz       = TimeZone.fromStr(meta["tz"] as Str ?: "", false) ?: TimeZone.cur

    switch (meta["userRole"])
    {
      case "su":    isSu = isAdmin = true
      case "admin": isAdmin = true
    }
  }

  override const Str username
  override const Dict meta
  override const Ref id
  override const Str dis
  override const Bool isSu
  override const Bool isAdmin
  override const Str? email
  override const TimeZone tz
  override const DateTime mod

  override Str toStr() { username }

  override once HxUserAccess access() { HxUserAccess(this) }

}

**************************************************************************
** HxUserAccess
**************************************************************************

const class HxUserAccess : UserAccess
{
  new make(HxUser user)
  {
    this.user   = user
    this.allows = HxUserAllows(user)
  }

  const HxUser user

  const HxUserAllows allows

  override Bool canPointWriteAtLevel(Int level) { user.isAdmin }

  override Bool allow(Str action) { allows.contains(action) }
}

**************************************************************************
** HxUserAllows
**************************************************************************

@Js @NoDoc
const class HxUserAllows
{
  static const HxUserAllows empty := make(Str:Str[:])

  static new makeUser(User user)
  {
    list := user.meta["userAllow"] as List
    if (list == null || list.isEmpty) return empty
    acc := Str:Str[:].setList(list) { it.toStr }
    return make(acc)
  }

  Bool contains(Str name) { names.containsKey(name) }

  private new make(Str:Str names) { this.names = names }

  private const Str:Str names
}

