//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    3 Oct 2009  Brian Frank        Creation
//   22 Mar 2011  Brian Frank        Rename Permissions -> User
//    3 Jan 2016  Brian Frank        Refactor for 3.0
//    5 Feb 2020  Matthew Giannini   User is a Person
//    8 Jan 2021  Matthew GIannini   User is *not* a Person (removed Person API)
//   25 May 2021  Brian Frank        Haxall copy
//

using xeto
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

  ** User timezone
  @NoDoc abstract TimeZone tz()

  ** User record modified time
  @NoDoc abstract DateTime mod()

  ** Is this user account disabled
  @NoDoc Bool isDisabled()
  {
    // check disabled flag
    if (meta.has("disabled")) return true

    // check expired
    expires := meta["expires"] as Date
    if (expires == null) return false
    return Date.today >= expires
  }

  ** Access control APIs
  @NoDoc abstract UserAccess access()

  ** Return if given `skyarcd::Proj` instance is accessible
  ** by this user's configured `projAccessFilter`.
  ** TODO: just shim for now
  @NoDoc Bool isProjAccessible(Obj proj)
  {
    //meta := (Dict)proj.typeof.method("meta").callOn(proj, null)
    //return access.proj.matches(meta)
return true
  }
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

  ** Authenticated username associated with the session
  Str username() { user.username }
}

**************************************************************************
** UserAccess
**************************************************************************

@Js @NoDoc
const mixin UserAccess
{
  ** Can the given user override level 1, 8, or 17 (relinquish default)
  abstract Bool canPointWriteAtLevel(Int level)

  ** Allow action/func name for given user
  abstract Bool allow(Str action)
}

