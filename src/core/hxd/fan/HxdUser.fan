//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 May 2021  Brian Frank  Creation
//

using haystack
using hx

**
**  Haxall daemon implementation of HxUser
**
const class HxdUser : HxUser
{
  new make(Dict meta)
  {
    this.meta     = meta
    this.username = meta->username
    this.dis      = meta["dis"] ?: username
    this.email    = meta["email"] as Str

    switch (meta["userRole"])
    {
      case "su":    isSu = isAdmin = true
      case "admin": isAdmin = true
    }
  }

  override const Str username
  override const Dict meta
  override const Str dis
  override const Bool isSu
  override const Bool isAdmin
  override const Str? email
}



