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
** HxBackgroundMgr
**
const class HxBackgroundMgr : Actor
{

  new make(HxProj proj) : super(proj.actorPool)
  {
    this.proj = proj
  }

  const HxProj proj

  Void start()
  {
    // this must be called after libs are started/readied
    startTicks.val = Duration.nowTicks
    send(checkMsg)
  }

  Void forceSteadyState()
  {
    send(forceSteadyStateMsg).get(1sec)
  }

  override Obj? receive(Obj? msg)
  {
    // if daemon shutdown we are all done
    if (!proj.isRunning) return null

    // dispatch message
    if (msg === checkMsg) return onCheck
    if (msg === forceSteadyStateMsg) return onForceSteadyState
    throw Err("Unknown msg: $msg")
  }

  private Obj? onCheck()
  {
    // schedule next background housekeeping
    sendLater(freq, checkMsg)

    // check for steady state transitions
    checkSteadyState

    // update now cached DateTime
    now := DateTime.now(null)
    proj.nowRef.val = now

    // check schedules
    proj.obs.schedule.check(now)

    // check watches
    proj.watch.checkExpires

    return null
  }

  private Obj? onForceSteadyState()
  {
    transitionToSteadyState
    return null
  }

  private Void checkSteadyState()
  {
    if (proj.isSteadyState) return

    config := steadyStateConfig
    elapsed := Duration.nowTicks - startTicks.val
    if (elapsed >= config.ticks)
      transitionToSteadyState
  }

  private Void transitionToSteadyState()
  {
    proj.log.info("Steady state")
    proj.stateStateRef.val = true
    proj.exts.list.each |ext| { ((HxExtSpi)ext.spi).steadyState }
  }

  private Duration steadyStateConfig()
  {
    Duration? x
    try
      x = (proj.meta["steadyState"] as Number)?.toDuration
    catch (Err e)
      {}
    if (x == null) x = 10sec
    if (x > 1hr)   x = 1hr
    return x
  }

  const HxMsg checkMsg := HxMsg("check")
  const HxMsg forceSteadyStateMsg := HxMsg("forceSteadyState")
  const Duration freq := 100ms
  const AtomicInt startTicks := AtomicInt(0)
}

