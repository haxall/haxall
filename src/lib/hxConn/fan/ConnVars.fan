//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Jan 2022  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hx
using hxPoint

**
** ConnVars stores the mutable variables managed by ConnMgr.
** We expose them via atomics for details debug.
**
internal const final class ConnVars
{

//////////////////////////////////////////////////////////////////////////
// Access
//////////////////////////////////////////////////////////////////////////

  ConnStatus status() { statusRef.val }

  ConnState state() { stateRef.val }

  Str:Str openPins() { openPinsRef.val }

  Int lingerUntil() { lingerUntilRef.val }

  Int lastPoll() { lastPollRef.val }

  Int lastPing() { lastPingRef.val }

  Int lastOk() { lastOkRef.val }

  Int lastErr() { lastErrRef.val }

  Int lastAttempt() { lastErr.max(lastOk) }

  Err? err()  { errRef.val }

//////////////////////////////////////////////////////////////////////////
// Pin Transitions
//////////////////////////////////////////////////////////////////////////

  internal Bool openPin(Str app)
  {
    pins := openPins
    if (pins.containsKey(app)) return false
    openPinsRef.val = pins.dup.set(app, app).toImmutable
    return true
  }

  internal Bool closePin(Str app)
  {
    pins := openPins
    if (!pins.containsKey(app)) return false
    openPinsRef.val = pins.dup { remove(app) }.toImmutable
    return true
  }

  internal Void clearPins()
  {
    openPinsRef.val = Str:Str[:].toImmutable
  }

//////////////////////////////////////////////////////////////////////////
// Linger Transitions
//////////////////////////////////////////////////////////////////////////

  Bool lingerExpired()
  {
    deadline := lingerUntil
    return deadline > 0 && deadline <= Duration.nowTicks
  }

  internal Void setLinger(Duration x)
  {
    lingerUntilRef.val = lingerUntil.max(Duration.nowTicks + x.ticks)
  }

  internal Void clearLinger()
  {
    lingerUntilRef.val = 0
  }

//////////////////////////////////////////////////////////////////////////
// Stat Transitions
//////////////////////////////////////////////////////////////////////////

  internal Void polled() { lastPollRef.val = Duration.nowTicks }

  internal Void pinged() { lastPingRef.val = Duration.nowTicks }

  internal Void resetStats()
  {
    lingerUntilRef.val = 0
    lastPollRef.val = 0
    lastPingRef.val = 0
    lastOkRef.val = 0
    lastErrRef.val = 0
  }

//////////////////////////////////////////////////////////////////////////
// State/Status Transitions
//////////////////////////////////////////////////////////////////////////

  internal Void updateState(ConnState state)
  {
    stateRef.val = state
  }

  internal Void updateStatus(ConnStatus status, ConnState state)
  {
    statusRef.val = status
    stateRef.val = state
  }

  internal Void updateOk()
  {
    lastOkRef.val = Duration.nowTicks
    errRef.val = null
  }

  internal Void updateErr(Err err)
  {
    lastErrRef.val = Duration.nowTicks
    errRef.val = err
  }

//////////////////////////////////////////////////////////////////////////
// Debugging
//////////////////////////////////////////////////////////////////////////

  Void details(StrBuf s)
  {
    s.add("""status          $status
             state:          $state
             openPins:       $openPins.keys.sort
             lingering:      $detailsLinger
             lastPoll:       ${Etc.debugDur(lastPoll)}
             lastPing:       ${Etc.debugDur(lastPing)}
             lastOk:         ${Etc.debugDur(lastOk)}
             lastErr         ${Etc.debugDur(lastErr)}
             err:            ${Etc.debugErr(err)}
             """)
  }

  private Str detailsLinger()
  {
    lingerUntil <= 0 ? "na" : Etc.debugDur(lingerUntil)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const AtomicRef statusRef := AtomicRef(ConnStatus.unknown)
  private const AtomicRef stateRef := AtomicRef(ConnState.closed)
  private const AtomicRef openPinsRef := AtomicRef(Str:Str[:].toImmutable)
  private const AtomicInt lingerUntilRef := AtomicInt()
  private const AtomicInt lastPollRef := AtomicInt()
  private const AtomicInt lastPingRef := AtomicInt()
  private const AtomicInt lastOkRef := AtomicInt()
  private const AtomicInt lastErrRef := AtomicInt()
  private const AtomicRef errRef := AtomicRef(null)
}

