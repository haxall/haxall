//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

**
** Converts a fraction into the number of stages to run, out of `n`.  Stage
** i starts at the threshold (i-1)/n.  `out` moves up when `in` goes above
** the next stage's threshold by more than `h`, and down when `in` drops
** below the current stage's threshold by more than `h`.  After each change
** `out` is held for at least `holdDuration`, on the component's own clock.
** A step of the clock backward counts as no time, but the time between the
** executes either side of it is lost too, up to the size of the step.
** While the host clock is behind the latest time it has seen, the component
** executes every cycle.  This is the CDL `Integers.Stage` block.  A change
** of `n` lowers `out` to the new `n` if it is above it and does not restart
** the hold.  An `n` below 1, an `h` outside 0.001/n to 0.5/n or a negative
** `holdDuration` is a fault, and so is a NaN `in` with a valid status:
** `out` holds its value with status fault.  A null `in` sets `out` to null,
** and an invalid `in` holds `out` with that status.  At stage `n` the two
** thresholds meet, so `out` leaves `n` with no hysteresis, as in MBL (the
** Modelica Buildings Library).
**
** Departure from MBL: this component fires on the level of its condition,
** not its rise, which matches MBL for any `holdDuration` above 0.  At a
** hold of 0, MBL's block can stick at stage `n` or 0, near a threshold, or
** when `in` starts more than `h` from 0, and this component does not.
**
@Gen
class Stage : HxComp
{
  ** Input, a fraction from 0 to 1
  @Gen virtual StatusNumber? in() { get("in") }

  ** Number of stages, at least 1
  @Gen virtual Int n { get {get("n")} set {set("n", it)} }

  ** Minimum time `out` is held after each change
  @Gen virtual Duration holdDuration { get {get("holdDuration")} set {set("holdDuration", it)} }

  ** Hysteresis on each threshold, 0.001/n to 0.5/n, or 0.02/n when null
  @Gen virtual Float? h { get {get("h")} set {set("h", it)} }

  ** The value of `out` from the first execute until its first change
  @Gen virtual Int initVal { get {get("initVal")} set {set("initVal", it)} }

  ** The number of stages to run
  @Gen virtual StatusNumber? out() { get("out") }

  new make()
  {
  }

  ** Has the first valid in been seen
  private Bool initialized

  ** The n the state was built for
  private Int stages

  ** The current stage, CDL's y
  private Int outVal

  ** upperThreshold and lowerThreshold, as of the last execute
  private Float upper
  private Float lower

  ** checkUpper and checkLower, as of the last execute
  private Bool checkUpper
  private Bool checkLower

  ** When the hold last started, on the own clock: tNext - holdDuration
  private Int? heldAt

  ** The component's own clock
  private OwnClock clock := OwnClock()

  ** Frequency while no hold is running
  private static const Duration idleFreq := 1min

  override Duration? onExecuteFreq()
  {
    // timed comps are collected when mounted, so never return null; while
    // the clock is behind, onExecute asks for every cycle itself
    if (!initialized || heldAt == null || !clock.started || clock.behind) return idleFreq
    left := holdDuration - Duration(clock.ticks - heldAt)
    return left > 0ns ? left : idleFreq
  }

  override Void onExecute()
  {
    // while the clock is behind, ask for the next cycle (see OwnClock)
    now := clock.tick(cx.now)
    if (clock.behind) execute

    u := in
    if (u == null) return set("out", null)
    status := u.status

    // a configuration fault is checked before the invalid rule
    k := n
    hys := effectiveH(k)
    if (isFault(k, hys)) return write(held, status.set(Status.fault))

    // CDL's n cannot change at runtime; an edit keeps the running stages
    if (initialized && k != stages) renumber(k)

    if (!status.isValid)
    {
      if (initialized && out != null) write(outVal, status)
      return
    }

    // a NaN under an invalid status falls under the invalid rule above
    if (u.num.isNaN) return write(held, status.set(Status.fault))

    x := u.num.toFloat
    if (!initialized)
    {
      // CDL's initial equations; the when clause does not fire at the
      // start time, but the tests are evaluated there
      this.initialized = true
      this.stages = k
      this.outVal = initVal
      this.upper = 0f
      this.lower = 0f
      this.checkUpper = false
      this.checkLower = true
      this.heldAt = now
      checkBands(x, hys)
      return write(outVal, status)
    }

    checkBands(x, hys)

    // CDL's when clause, fired on the condition's level rather than its
    // rise, so a hold of 0 cannot stick; the same as MBL for a hold above 0
    if (condition(now))
    {
      this.heldAt = now
      this.outVal = stage(x, k)
      this.upper = outVal == k ? thr(k, k) : thr(outVal + 1, k)
      this.lower = outVal == 0 ? lower : thr(outVal, k)

      // the event iteration: test again against the new thresholds
      checkBands(x, hys)
    }
    write(outVal, status)
  }

  ** Move the state to k stages, as a firing at the lowered stage would
  private Void renumber(Int k)
  {
    this.stages = k
    this.outVal = outVal.min(k)
    this.upper = outVal == k ? thr(k, k) : thr(outVal + 1, k)
    this.lower = outVal == 0 ? 0f : thr(outVal, k)
  }

  ** CDL's checkUpper and checkLower, with hysteresis h
  private Void checkBands(Float x, Float hys)
  {
    this.checkUpper = (!checkUpper && x > upper + hys) || (checkUpper && x >= upper - hys)
    this.checkLower = (!checkLower && x > lower + hys) || (checkLower && x >= lower - hys)
  }

  ** time >= pre(tNext) and (checkUpper or not checkLower)
  private Bool condition(Int now)
  {
    now - heldAt >= holdDuration.ticks && (checkUpper || !checkLower)
  }

  ** CDL's y: n at or above staThr[n], else the stage whose band holds x
  private static Int stage(Float x, Int k)
  {
    if (x >= thr(k, k)) return k
    y := 0
    for (i := 2; i <= k; ++i)
      if (x < thr(i, k) && x >= thr(i - 1, k)) y += i - 1
    return y
  }

  ** staThr[i] = (i - 1)/n
  private static Float thr(Int i, Int k) { (i - 1).toFloat / k.toFloat }

  ** h, or its CDL default 0.02/n when null
  private Float effectiveH(Int k)
  {
    v := h
    if (v != null) return v
    return k < 1 ? Float.nan : 0.02f / k.toFloat
  }

  ** Configuration faults; a NaN h fails the compares, so it faults too
  private Bool isFault(Int k, Float hys)
  {
    if (k < 1 || holdDuration < 0ns) return true
    return !(hys >= 0.001f / k.toFloat && hys <= 0.5f / k.toFloat)
  }

  ** The value a fault holds: out, or initVal before the first value
  private Int held() { initialized ? outVal : initVal }

  ** Write out when its value or status changes
  private Void write(Int v, Status status)
  {
    o := out
    if (o != null && o.num.toInt == v && o.status == status) return
    set("out", StatusNumber(Number.makeInt(v), status))
  }
}
