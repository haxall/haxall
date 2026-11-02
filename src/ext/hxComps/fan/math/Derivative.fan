//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

**
** Approximates `k` times the derivative of `in`, filtered with time
** constant `T`: the transfer function `k * s / (T * s + 1)`, stepped by
** backward Euler, which is stable for any `T` and cycle.  This is the
** CDL `Reals.Derivative` block.
**
** Unlike CDL, `k` and `timeConst` (CDL's `T`) are slots, not inputs:
** link a `StatusNumberToNumber` to schedule them.  A stall, a step
** longer than both 1min and the larger of `timeConst` and 10 times the
** longest of the last 8 steps, is a gap, and so is time while `in` is
** null, invalid or a fault: `out` holds and the next step starts from
** there.  A null `in` sets `out` to null, an invalid `in` holds `out`
** with its status, and a fault holds `out` with fault, never null: a
** `timeConst` below 0, not finite or with a unit that is not a time, a
** `k` or `yStart` that is not finite, an `in` that is not finite, or a
** step that overflows.  `out` has no unit.
**
@Gen
class Derivative : HxComp
{
  ** Input to differentiate
  @Gen virtual StatusNumber? in() { get("in") }

  ** Gain
  @Gen virtual Number k { get {get("k")} set {set("k", it)} }

  ** Time constant `T` of the filter, in seconds unless it has a time unit
  @Gen virtual Number timeConst { get {get("timeConst")} set {set("timeConst", it)} }

  ** The value of `out` at the first execute
  @Gen virtual Number yStart { get {get("yStart")} set {set("yStart", it)} }

  ** Filtered derivative of `in`
  @Gen virtual StatusNumber? out() { get("out") }

  new make() {}

  ** Has the first valid in been seen
  private Bool initialized

  ** Did the last execute take the valid path, so x follows in
  private Bool valid

  ** The CDL state x and the last value written to out
  private Float x
  private Float y

  ** CDL Constants.eps, and the floor CDL puts under T
  private static const Float eps := 1E-15f
  private static const Float minT := 1E-13f

  private CycleClock clock := CycleClock()

  override Void onExecute()
  {
    // execute on every cycle: each step is the time since the last one
    execute

    // a stall is a gap: a slope over it would be invented
    dt := CycleClock.sec(clock.step(cx.now, CycleClock.ticks(seconds(timeConst) ?: 0f)))
    stalled := clock.stalled
    wasValid := this.valid
    this.valid = false

    u := in
    if (u == null) return set("out", null)

    status := u.status
    kf := k.toFloat
    y0 := yStart.toFloat
    t := seconds(timeConst)
    held := initialized ? y : y0

    // configuration faults are checked before the invalid rule
    if (t == null || !(t >= 0f) || !CycleClock.isFinite(t) || !CycleClock.isFinite(kf) || !CycleClock.isFinite(y0))
      return write(held, status.set(Status.fault))

    // an invalid in holds the value of out, null included
    if (!status.isValid)
    {
      if (out != null) write(held, status)
      return
    }

    // a non-finite in with a valid status is a fault
    v := u.num.toFloat
    if (!CycleClock.isFinite(v)) return write(held, status.set(Status.fault))

    // CDL: T_nonZero = max(T, 100*eps)
    tn := t.max(minT)
    nx := x
    ny := y
    stepping := false
    if (!initialized)
    {
      // CDL: x = if abs(k) < eps then u else u - T*y_start/k, so that
      // y = k/T_nonZero*(u - x) is y_start*T/T_nonZero, or 0
      if (kf.abs < eps) { nx = v; ny = 0f }
      else { nx = v - t * y0 / kf; ny = y0 * (t / tn) }
    }
    else if (!wasValid || stalled)
    {
      // first valid execute after a gap or a stall: hold out, no step
      nx = kf.abs < eps ? v : v - tn * y / kf
    }
    else if (dt > 0f)
    {
      // CDL: der(x) = (u - x)/T, y = k/T*(u - x), by backward Euler
      d := tn + dt
      ny = kf * (v - x) / d
      nx = x + dt * (v - x) / d
      stepping = true
    }

    // an overflow keeps the state and is stepped again next execute, so
    // the fault holds for as long as the overflow does
    if (!CycleClock.isFinite(nx) || !CycleClock.isFinite(ny))
    {
      this.valid = stepping
      return write(held, status.set(Status.fault))
    }
    this.x = nx
    this.y = ny
    this.initialized = true
    this.valid = true
    write(y, status)
  }

  ** The time constant in seconds, or null for a unit that is not a time
  private static Float? seconds(Number n)
  {
    if (n.unit == null) return n.toFloat
    d := Number(1f, n.unit).toDuration(false)
    if (d == null) return null
    return n.toFloat * CycleClock.sec(d.ticks)
  }

  ** Write out unless it already has this value and status.  A value
  ** that is not finite is written as NaN with fault.
  private Void write(Float v, Status status)
  {
    if (!CycleClock.isFinite(v)) { v = Float.nan; status = status.set(Status.fault) }
    o := out
    n := Number(v)
    if (o != null && o.num == n && o.status == status) return
    set("out", StatusNumber(n, status))
  }
}
