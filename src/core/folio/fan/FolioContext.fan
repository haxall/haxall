//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Jun 2016  Brian Frank  Creation
//

using concurrent
using xeto

**
** FolioContext is used to plug-in access control checks
**
@NoDoc
mixin FolioContext : ActorContext
{

  ** Current context for actor thread
  @NoDoc static FolioContext? curFolio(Bool checked := true)
  {
    cx := Actor.locals[actorLocalsKey]
    if (cx != null) return cx
    if (checked) throw ContextUnavailableErr("No FolioContext available")
    return null
  }

  ** Return if context has read access to given record
  abstract Bool canRead(Dict rec)

  ** Return if context has write (update/delete) access to given record
  abstract Bool canWrite(Dict rec)

  ** Return an immutable thread safe object which will be passed thru
  ** the commit process and available via the FolioHooks callbacks.
  ** This is typically the User instance.
  abstract Obj? commitInfo()
}

