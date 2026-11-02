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
** Measures how long `in` has been true.  `out` is the time in seconds
** since `in` turned true, or 0 while it is false.  `passed` turns true
** when that time reaches `threshold`, and false when `in` turns false.
** With a threshold of 0, `passed` stays false until `in` turns true.  A
** negative threshold acts as 0.  This is the CDL `Logical.Timer` block.
** While `in` is true, `out` refreshes once a second and `passed` turns true
** on the first cycle at or after the threshold.  A step of the clock
** backward counts as no time, but the time between the executes either side
** of it is lost too, up to the size of the step.  While the host clock is
** behind the latest time it has seen, the component executes every cycle.
** A null `in` sets both outputs to null and an invalid `in` holds them,
** both keeping the state.
**
@Gen
class Timer : HxComp
{
  ** Input that runs the timer while true
  @Gen virtual StatusBool? in() { get("in") }

  ** Time at which `passed` turns true
  @Gen virtual Duration threshold { get {get("threshold")} set {set("threshold", it)} }

  ** Time in seconds since `in` turned true, or 0 while `in` is false
  @Gen virtual StatusNumber? out() { get("out") }

  ** True once `out` has reached `threshold`
  @Gen virtual StatusBool? passed() { get("passed") }

  new make()
  {
  }

  private Bool initialized
  private Bool lastIn

  ** When in turned true, on the own clock
  private Int entryAt

  private Bool passedVal
  private OwnClock clock := OwnClock()
  private static const Duration idleFreq := 1min

  ** Frequency while in is true, so out follows the elapsed time
  private static const Duration runFreq := 1sec

  private static const Unit secUnit := Unit("s")

  override Duration? onExecuteFreq()
  {
    // timed comps are collected when mounted, so never return null
    if (!initialized || !clock.started || clock.behind || !lastIn) return idleFreq

    // refresh out every second, or sooner to set passed on time.  No
    // DateTime is built, so a threshold past 2099 cannot throw.
    if (passedVal) return runFreq
    left := threshold - elapsed(clock.ticks)
    return left > 0ns ? left.min(runFreq) : runFreq
  }

  override Void onExecute()
  {
    // while the host clock is behind, execute every cycle (see OwnClock)
    now := clock.tick(cx.now)
    if (clock.behind) execute

    // null in keeps the state
    inVal := this.in
    if (inVal == null)
    {
      set("out", null)
      set("passed", null)
      return
    }

    // invalid in holds both outputs, which stay null after a null in
    status := inVal.status
    if (!status.isValid)
    {
      o := out
      p := passed
      if (initialized && o != null && p != null)
      {
        set("out", StatusNumber(o.num, status))
        set("passed", StatusBool(p.val, status))
      }
      return
    }

    u := inVal.val
    if (!initialized)
    {
      this.initialized = true
      this.entryAt = now
      this.passedVal = u && threshold <= 0ns
    }
    else if (u && !lastIn)
    {
      this.entryAt = now
      this.passedVal = threshold <= 0ns
    }
    else if (u)
    {
      if (elapsed(now) >= threshold) this.passedVal = true
    }
    else if (lastIn)
    {
      this.passedVal = false
    }
    this.lastIn = u

    y := u ? elapsed(now) : 0ns
    set("out", StatusNumber(Number.makeDuration(y, secUnit), status))
    set("passed", StatusBool(passedVal, status))
  }

  ** Time since in turned true, on the own clock
  private Duration elapsed(Int now) { Duration(now - entryAt) }
}
