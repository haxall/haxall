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
    // this must be called after libs are started/readied
    startTicks.val = Duration.nowTicks
    send("bg")
  }

  override Obj? receive(Obj? msg)
  {
    // if daemon shutdown we are all done
    if (!rt.isRunning) return null

    // schedule next background housekeeping
    sendLater(freq, "bg")

    // check for steady state transitions
    checkSteadyState

    // update now cached DateTime
    now := DateTime.now(null)
    rt.nowRef.val = now

    // check schedules
    rt.obs.schedule.check(now)

    // check watches
    rt.watch.checkExpires

    return null
  }

  private Void checkSteadyState()
  {
    if (rt.isSteadyState) return

    config := steadyStateConfig
    elapsed := Duration.nowTicks - startTicks.val
    if (elapsed >= config.ticks)
    {
      rt.log.info("Steady state")
      rt.stateStateRef.val = true
      rt.libs.list.each |lib| { ((HxdLibSpi)lib.spi).steadyState }
    }
  }

  private Duration steadyStateConfig()
  {
    Duration? x
    try
      x = (rt.meta["steadyState"] as Number)?.toDuration
    catch (Err e)
      {}
    if (x == null) x = 10sec
    if (x > 1hr)   x = 1hr
    return x
  }

  const Duration freq := 100ms
  const AtomicInt startTicks := AtomicInt(0)
}