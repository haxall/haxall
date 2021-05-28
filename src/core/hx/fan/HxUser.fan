//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 May 2021  Brian Frank  Creation
//

using haystack
using axon
using folio

**
** Haxall user account
**
const mixin HxUser
{
  ** Ref identifier
  abstract Ref id()

  ** Username identifier
  abstract Str username()

  ** User meta data as Haystack dict
  abstract Dict meta()

  ** Display string for user
  abstract Str dis()

  ** Does this user have superuser permissions
  abstract Bool isSu()

  ** Does this user have admin permissions
  abstract Bool isAdmin()

  ** Email address if configured
  abstract Str? email()
}