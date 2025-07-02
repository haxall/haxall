//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Mar 2032  Brian Frank  Creation
//

using xeto
using haystack
using hx

**
** HxUser implementation for ShellContext
**
internal const class ShellUser : HxUser
{
  new make()
  {
    this.username = Etc.toTagName(Env.cur.user)
    this.id       = Ref(RefSchemes.user + ":" + username)
    this.mod      = DateTime.nowUtc
    this.meta     = Etc.dict3("username", username, "id", id, "mod", mod)
    this.dis      = username
    this.isAdmin  = true
    this.isSu     = true
    this.access   = ShellUserAccess()
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

internal const class ShellUserAccess : HxUserAccess
{
  override Bool canPointWriteAtLevel(Int level) { true }
}

