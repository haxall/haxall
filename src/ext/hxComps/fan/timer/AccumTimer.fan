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
** Accumulates the time `in` is true.  `out` is the total in seconds since
** the last reset, and holds while `in` is false.  `passed` turns true when
** `out` reaches `threshold` and stays true until a reset.  With a threshold
** of 0 or less, `passed` is true from the start and right after each
** reset.  A rise of `reset` sets `out` to 0 and wins over a rise of `in` at
** the same time.  This is the CDL `Logical.TimerAccumulating` block.  While
** `in` is true, `out` refreshes once a second and `passed` turns true on
** the first cycle at or after the threshold.  A fall of `in` seen in the
** execute that takes the total to the threshold or past it leaves `passed`
** false, as MBL (the Modelica Buildings Library) does for a fall at the
** threshold.  After such a fall, `passed` turns true on the next rise of
** `in`, unless a reset comes first.  A step of the clock backward counts as
** no time, but the time between the executes either side of it is lost too,
** up to the size of the step.  While the host clock is behind the latest
** time it has seen, the component executes every cycle.
**
** The total starts from 0 on the first valid execute, so it does not
** survive a restart.  A null `in` or `reset` sets both outputs to null and
** an invalid one holds them, both keeping the state.  Time while `in` is
** null or invalid counts if `in` was true before it.
**
@Gen
class AccumTimer : HxComp
{
  ** Input that runs the timer while true
  @Gen virtual StatusBool? in() { get("in") }

  ** Sets `out` to 0 when it turns true.  Link a `BoolConst` false when
  ** unused: an unlinked `reset` keeps both outputs null.
  @Gen virtual StatusBool? reset { get {get("reset")} set {set("reset", it)} }

  ** Time at which `passed` turns true
  @Gen virtual Duration threshold { get {get("threshold")} set {set("threshold", it)} }

  ** Time in seconds that `in` has been true since the last reset
  @Gen virtual StatusNumber? out() { get("out") }

  ** True once `out` has reached `threshold`
  @Gen virtual StatusBool? passed() { get("passed") }

  new make()
  {
  }

  private Bool initialized
  private Bool lastIn
  private Bool lastReset

  ** When in last turned true or the timer was reset, on the own clock
  private Int entryAt

  ** Time accumulated up to the last fall of in
  private Duration acc := 0ns

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
    left := threshold - acc - elapsed(clock.ticks)
    return left > 0ns ? left.min(runFreq) : runFreq
  }

  override Void onExecute()
  {
    // while the host clock is behind, execute every cycle (see OwnClock)
    now := clock.tick(cx.now)
    if (clock.behind) execute

    // null input keeps the state
    u := this.in
    r := this.reset
    if (u == null || r == null)
    {
      set("out", null)
      set("passed", null)
      return
    }

    // invalid input holds both outputs, null after a null input
    status := u.status.merge(r.status)
    if (!u.status.isValid || !r.status.isValid)
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

    uv := u.val
    rv := r.val
    if (!initialized)
    {
      // CDL gives the same start whatever in and reset are at init
      this.initialized = true
      this.entryAt = now
      this.acc = 0ns
      this.passedVal = threshold <= 0ns
    }
    else if (rv && !lastReset)
    {
      // a reset wins over a rise of in
      this.entryAt = now
      this.acc = 0ns
      this.passedVal = threshold <= 0ns
    }
    else if (uv && !lastIn)
    {
      this.entryAt = now
      this.passedVal = threshold <= acc
    }
    else if (uv)
    {
      if (acc + elapsed(now) >= threshold) this.passedVal = true
    }
    else if (lastIn)
    {
      this.acc = acc + elapsed(now)
    }
    this.lastIn = uv
    this.lastReset = rv

    y := uv ? acc + elapsed(now) : acc
    set("out", StatusNumber(Number.makeDuration(y, secUnit), status))
    set("passed", StatusBool(passedVal, status))
  }

  ** Time since entryAt, on the own clock
  private Duration elapsed(Int now) { Duration(now - entryAt) }
}
