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
    this.access   = HxUserAccess(this)

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
  override const DateTime mod
  override const HxUserAccess access

  override Str toStr() { username }
}

**************************************************************************
** HxUserAccess
**************************************************************************

const class HxUserAccess : UserAccess
{
  new make(HxUser user) { this.user = user }
  const HxUser user
  override Bool canPointWriteAtLevel(Int level) { user.isAdmin }
}

