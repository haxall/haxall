//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 May 2021  Brian Frank  Creation
//

using concurrent
using haystack
using axon
using folio

**
** Haxall execution and security context.
**
abstract class HxContext : AxonContext, HaystackContext, FolioContext
{

//////////////////////////////////////////////////////////////////////////
// Current
//////////////////////////////////////////////////////////////////////////

  ** Current Haxall context for actor thread
  @NoDoc static HxContext? curHx(Bool checked := true)
  {
    cx := Actor.locals[Etc.cxActorLocalsKey]
    if (cx != null) return cx
    if (checked) throw Err("No HxContext available")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Runtime associated with this context
  abstract HxRuntime rt()

  ** Folio database for the runtime
  abstract Folio db()

  ** User account associated with this context
  abstract HxUser user()

  ** About data to use for HTTP API
  @NoDoc abstract Dict about()

//////////////////////////////////////////////////////////////////////////
// Security
//////////////////////////////////////////////////////////////////////////

  ** If missing superuser permission, throw PermissionErr
  virtual Void checkSu(Str action)
  {
    if (!user.isSu)
      throw PermissionErr("Missing 'su' permission: $action")
  }

  ** If missing admin permission, throw PermissionErr
  virtual Void checkAdmin(Str action)
  {
    if (!user.isAdmin)
      throw PermissionErr("Missing 'admin' permission: $action")
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Resolve a normalized virtual file system URI.
  ** Apply security checks using this context's user.
  @NoDoc abstract File fileResolve(Uri uri)

//////////////////////////////////////////////////////////////////
// Feed (SkySpark Only)
//////////////////////////////////////////////////////////////////////////

  @NoDoc virtual Bool feedIsEnabled() { false }

  @NoDoc virtual Void feedAdd(HxFeed feed, [Str:Obj?]? meta := null) { throw UnsupportedErr() }

}

**************************************************************************
** HxFeed  (SkySpark Only)
**************************************************************************

@NoDoc const mixin HxFeed { protected abstract Grid onPoll() }

