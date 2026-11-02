//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jun 2025  Matthew Giannini  Creation
//

using xeto
using haystack

**
** Bool delay
**
** A rising `in` sets `out` true after `onDelay`, and a falling `in` sets
** it false after `offDelay`.  With `offDelay` of zero this is the CDL
** `Logical.TrueDelay` block.  A change to a delay applies to a pending
** timer.  A step of the clock backward counts as no time, but the time
** between the executes either side of it is lost too, up to the size of the
** step.  While the host clock is behind the latest time it has seen, the
** component executes every cycle.  A null `in` sets `out` and `outNot` to
** null and an invalid `in` holds them, both keeping the timer state.
**
@Gen
class BoolDelay : HxComp
{
  ** Input to the delay.
  @Gen virtual StatusBool? in() { get("in") }

  ** How long to wait before setting the out slot to true when
  ** the in slot transitions to true.
  @Gen virtual Duration onDelay { get {get("onDelay")} set {set("onDelay", it)} }

  ** How long to wait before setting the out slot to false when
  ** the in slot transitions to false.
  @Gen virtual Duration offDelay { get {get("offDelay")} set {set("offDelay", it)} }

  ** The value of the in slot after any delays are accounted for.
  @Gen virtual StatusBool? out() { get("out") }

  ** The inverse of the current out slot.
  @Gen virtual StatusBool? outNot() { get("outNot") }

  ** If true, a true in waits for onDelay on the first valid execute,
  ** including after a restart.  If false, out takes in at once then.
  @Gen virtual Bool delayOnInit { get {get("delayOnInit")} set {set("delayOnInit", it)} }

  new make()
  {
  }

  private Bool initialized
  private Bool lastIn
  private Bool outVal

  ** When the pending timer was armed on the own clock, null if none
  private Int? armedAt

  ** Is the pending timer the on-timer (true) or the off-timer (false)
  private Bool armedOn

  private OwnClock clock := OwnClock()
  private static const Duration idleFreq := 1min

  override Duration? onExecuteFreq()
  {
    // timed comps are collected when mounted, so never return null
    if (armedAt == null || !clock.started || clock.behind) return idleFreq

    // time left from the last execute, without a DateTime so a deadline
    // past 2099 cannot throw
    left := delay - Duration(clock.ticks - armedAt)
    return left > 0ns ? left : idleFreq
  }

  override Void onExecute()
  {
    // while the host clock is behind, execute every cycle (see OwnClock)
    now := clock.tick(cx.now)
    if (clock.behind) execute

    // null in keeps the state, so a returning in resumes a pending timer
    inVal := this.in
    if (inVal == null)
    {
      set("out", null)
      set("outNot", null)
      return
    }

    // invalid in holds out, which stays null after a null in
    if (!inVal.status.isValid)
    {
      if (initialized && out != null) write(inVal.status)
      return
    }

    u := inVal.val
    if (!initialized) init(u, now)
    else if (u != lastIn) edge(u, now)
    checkTimer(u, now)
    write(inVal.status)
  }

  ** First valid in, per the CDL TrueDelay initial equations
  private Void init(Bool u, Int now)
  {
    this.initialized = true
    this.lastIn = u
    if (delayOnInit) arm(true, now)
    this.outVal = (delayOnInit && onDelay > 0ns) ? false : u
  }

  private Void edge(Bool u, Int now)
  {
    this.lastIn = u
    if (u)
    {
      // a rise during the off-timer cancels it and out stays true
      if (armedAt != null && !armedOn) { this.armedAt = null; return }

      // with a delay of zero or less checkTimer fires this execute
      arm(true, now)
      this.outVal = false
    }
    else
    {
      // unlike TrueDelay, a true out first waits for the off-timer
      if (outVal) arm(false, now)
      else { this.armedAt = null; this.outVal = false }
    }
  }

  ** Fire the pending timer once its delay has run
  private Void checkTimer(Bool u, Int now)
  {
    if (armedAt == null) return
    if (now - armedAt < delay.ticks) return
    this.armedAt = null
    this.outVal = u
  }

  private Void arm(Bool on, Int now)
  {
    this.armedAt = now
    this.armedOn = on
  }

  private Duration delay() { armedOn ? onDelay : offDelay }

  private Void write(Status status)
  {
    set("out", StatusBool(outVal, status))
    set("outNot", StatusBool(!outVal, status))
  }
}
