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

}