//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 May 2021  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using axon
using folio

**
** Haxall execution and security context.
**
abstract class HxContext : AxonContext, FolioContext
{

//////////////////////////////////////////////////////////////////////////
// Current
//////////////////////////////////////////////////////////////////////////

  ** Current Haxall context for actor thread
  @NoDoc static HxContext? curHx(Bool checked := true)
  {
    cx := ActorContext.curx(false)
    if (cx != null) return cx
    if (checked) throw ContextUnavailableErr("No HxContext available")
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

  ** Authentication session associated with this context if applicable
  abstract HxSession? session(Bool checked := true)

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
// Feeds
//////////////////////////////////////////////////////////////////////////

  ** Feed initialization
  @NoDoc virtual HxFeedInit feedInit()
  {
    feedInitRef ?: throw Err("Feeds not supported")
  }

  ** Install feed initialization
  @NoDoc virtual HxFeedInit? feedInitRef

  ** In context a SkySpark feed
  @NoDoc virtual Bool feedIsEnabled() { false }

  ** Setup a feed (SkySpark only)
  @NoDoc virtual Void feedAdd(HxFeed feed, [Str:Obj?]? meta := null) {}

//////////////////////////////////////////////////////////////////////////
// SkySpark Context virtuals
//////////////////////////////////////////////////////////////////////////

  ** Clear read cache for subclasses
  @NoDoc virtual Void readCacheClear() {}

  ** Export to outpout stream - SkySpark only
  @NoDoc virtual Obj export(Dict req, OutStream out)
  {
    throw UnsupportedErr("Export not supported")
  }
}

