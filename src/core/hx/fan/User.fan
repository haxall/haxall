//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 May 2021  Brian Frank  Creation
//

using xeto
using axon
using folio

**
** User account
**
@Js
const mixin User
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

  ** User record modified time
   @NoDoc abstract DateTime mod()

  ** Access control APIs
  @NoDoc abstract UserAccess access()
}

**************************************************************************
** Session
**************************************************************************

**
** User authentication session
**
@Js
const mixin UserSession
{
  ** Unique identifier for session
  abstract Str key()

  ** Attestation session key used as secondary verification of cookie key
  abstract Str attestKey()

  ** Authenticated user associated with the sesssion
  abstract User user()
}

**************************************************************************
** UserAccess
**************************************************************************

@Js @NoDoc
const mixin UserAccess
{
  ** Can the given user override level 1, 8, or 17 (relinquish default)
  abstract Bool canPointWriteAtLevel(Int level)
}

