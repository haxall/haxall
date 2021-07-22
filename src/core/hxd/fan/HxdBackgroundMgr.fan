//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jun 2021  Brian Frank  Creation
//

using concurrent
using haystack
using obs
using folio
using hx

**
** HxdBackgroundMgr
**
internal const class HxdBackgroundMgr : Actor
{

  new make(HxdRuntime rt) : super(rt.hxdActorPool)
  {
    this.rt  = rt
  }

  const HxdRuntime rt

  Void start()
  {
    sendLater(freq, "bg")
  }

  override Obj? receive(Obj? msg)
  {
    // if daemon shutdown we are all done
    if (!rt.isRunning) return null

    // schedule next background housekeeping
    sendLater(freq, "bg")

    // update now cached DateTime
    now := DateTime.now(null)
    rt.nowRef.val = now

    // check schedules
    rt.observables.schedule.check(now)
    return null
  }

  const Duration freq := 100ms

}