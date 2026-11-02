//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

**
** Holds `out` for a minimum time after each change, `trueHold` after it
** turns true and `falseHold` after it turns false.  A change of `in`
** passes to `out` at once unless a hold is running, and when the hold
** lapses `out` takes `in`.  This is the CDL `Logical.TrueFalseHold` block.
** A step of the clock backward counts as no time, but the time between the
** executes either side of it is lost too, up to the size of the step.
** While the host clock is behind the latest time it has seen, the component
** executes every cycle.  A null `in` sets `out` to null and an invalid `in`
** holds it, both keeping the state.
**
@Gen
class BoolHold : HxComp
{
  ** Input
  @Gen virtual StatusBool? in() { get("in") }

  ** Minimum time `out` stays true after it turns true.
  @Gen virtual Duration trueHold { get {get("trueHold")} set {set("trueHold", it)} }

  ** Minimum time `out` stays false after it turns false.  CDL defaults
  ** this to `trueHold`, so set both.
  @Gen virtual Duration falseHold { get {get("falseHold")} set {set("falseHold", it)} }

  ** The value of `in`, held for its minimum time after each change.
  @Gen virtual StatusBool? out() { get("out") }

  new make()
  {
  }

  private Bool initialized
  private Bool lastIn
  private Bool outVal

  ** When out last turned true on the own clock, null for never
  private Int? trueAt

  ** When out last turned false on the own clock, null for never
  private Int? falseAt

  private OwnClock clock := OwnClock()
  private static const Duration idleFreq := 1min

  override Duration? onExecuteFreq()
  {
    // timed comps are collected when mounted, so never return null
    if (!initialized || !clock.started || clock.behind || lastIn == outVal) return idleFreq

    // a change is pending: the time left on the longer hold, without a
    // DateTime so a deadline past 2099 cannot throw
    left := holdLeft(trueAt, trueHold).max(holdLeft(falseAt, falseHold))
    return left > 0ns ? left : idleFreq
  }

  override Void onExecute()
  {
    // while the host clock is behind, execute every cycle (see OwnClock)
    now := clock.tick(cx.now)
    if (clock.behind) execute

    // null in keeps the state
    inVal := this.in
    if (inVal == null) return set("out", null)

    // invalid in holds out, which stays null after a null in
    if (!inVal.status.isValid)
    {
      if (initialized && out != null) write(inVal.status)
      return
    }

    u := inVal.val
    this.lastIn = u
    if (!initialized)
    {
      this.initialized = true
      this.outVal = u
      if (u) this.trueAt = now
      else this.falseAt = now
    }
    else if (lapsed(now) && u != outVal)
    {
      this.outVal = u
      if (u) this.trueAt = now
      else this.falseAt = now
    }
    write(inVal.status)
  }

  private Bool lapsed(Int now)
  {
    elapsed(trueAt, now) >= trueHold && elapsed(falseAt, now) >= falseHold
  }

  ** Time since at on the own clock, or maxVal if never
  private static Duration elapsed(Int? at, Int now)
  {
    at == null ? Duration.maxVal : Duration(now - at)
  }

  ** Time left on a hold from the last execute
  private Duration holdLeft(Int? at, Duration hold)
  {
    if (at == null) return 0ns
    return hold - elapsed(at, clock.ticks)
  }

  private Void write(Status status)
  {
    set("out", StatusBool(outVal, status))
  }
}
