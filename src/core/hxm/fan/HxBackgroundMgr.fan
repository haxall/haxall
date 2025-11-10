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

  new make(HxRuntime rt) : super(rt.actorPool)
  {
    // check sys freq for obsSchedule, but for projects
    // put add some randomness to spread out CPU load
    this.rt = rt
    this.checkFreq = rt.isSys ? 100ms : 1ms * (800..1200).random
  }

  const HxRuntime rt

  Log log() { rt.log }

  Void forceSteadyState()
  {
    send(forceSteadyStateMsg).get(1sec)
  }

//////////////////////////////////////////////////////////////////////////
// Actor
//////////////////////////////////////////////////////////////////////////

  Void start()
  {
    // this must be called after libs are started/readied
    startTicks.val = Duration.nowTicks
    send(checkMsg)
  }

  override Obj? receive(Obj? msg)
  {
    // if daemon shutdown we are all done
    if (!rt.isRunning) return null

    // dispatch message
    if (msg === checkMsg) return onCheck
    if (msg === forceSteadyStateMsg) return onForceSteadyState
    throw Err("Unknown msg: $msg")
  }

  private Obj? onCheck()
  {
    // schedule next background housekeeping
    sendLater(checkFreq, checkMsg)

    // check for steady state transitions
    checkSteadyState

    // update now cached DateTime
    now := DateTime.now(null)
    rt.nowRef.val = now

    // check schedules
    rt.obs.schedule.check(now)

    // check watches
    rt.watch.checkExpires

    // check temp dir cleanup
    checkCleanupTempDir

    return null
  }

//////////////////////////////////////////////////////////////////////////
// Steady State
//////////////////////////////////////////////////////////////////////////

  private Obj? onForceSteadyState()
  {
    transitionToSteadyState
    return null
  }

  private Void checkSteadyState()
  {
    if (rt.isSteadyState) return

    config := steadyStateConfig
    elapsed := Duration.nowTicks - startTicks.val
    if (elapsed >= config.ticks)
      transitionToSteadyState
  }

  private Void transitionToSteadyState()
  {
    rt.log.info("Steady state")
    rt.stateStateRef.val = true
    rt.exts.listOwn.each |ext| { ((HxExtSpi)ext.spi).steadyState }
  }

  private Duration steadyStateConfig() { rt.meta.steadyState }

//////////////////////////////////////////////////////////////////////////
// Temp Dir Cleanup
//////////////////////////////////////////////////////////////////////////

  private Void checkCleanupTempDir()
  {
    if (Duration.nowTicks > checkTempDirDeadline.val)
    {
      cleanupTempDir
      checkTempDirDeadline.val = Duration.nowTicks + checkTempDirFreq.ticks
    }
  }

  private Void cleanupTempDir()
  {
    try
    {
      now := DateTime.now
      rt.tempDir.list.each |file|
      {
        if (file.modified == null || now - file.modified > tempFileExpiration)
        {
          try
            file.delete
          catch (Err e)
            log.err("Cannot delete temp file '$file': $e")
        }
      }
    }
    catch (Err e)
    {
      log.err("Cannot cleanup 'tempDir'", e)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  static const HxMsg checkMsg := HxMsg("check")
  static const HxMsg forceSteadyStateMsg := HxMsg("forceSteadyState")
  static const Duration tempFileExpiration := 1hr
  static const Duration checkTempDirFreq := 77sec

  const Duration checkFreq
  const AtomicInt startTicks := AtomicInt(0)
  const AtomicInt checkTempDirDeadline := AtomicInt(Duration.nowTicks + checkTempDirFreq.ticks)
}

