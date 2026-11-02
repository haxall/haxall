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
** Integrates `in` over time: `out` is `yStart` plus `k` times the
** integral of `in` since the first execute.  When `inReset` turns true,
** `out` is set to `inResetVal`, or to `yStart` when `inResetVal` is
** null.  This is the CDL `Reals.IntegratorWithReset` block.
**
** Unlike CDL, each step is the trapezoid from the last `in` to the current
** one, so `out` has direct feedthrough from `in`.  A stall, a step longer
** than both 1min and 10 times the longest of the last 8 steps, counts as
** the larger of the two.  Time while `in` is null, invalid or a fault is
** not integrated, and a reset while `inResetVal` is invalid or not finite
** waits until it is usable.  A null `in` sets `out` to null, an invalid
** `in` holds `out` with its status, and a fault holds `out` with fault,
** never null: a `k` or `yStart` that is not finite, an `in` that is not
** finite, or a step that overflows.  `out` has no unit.  The state is not
** persisted: after a restart `out` starts again from `yStart`.
**
@Gen
class Integrator : HxComp
{
  ** Input to integrate
  @Gen virtual StatusNumber? in() { get("in") }

  ** Resets `out` when it turns true.  Optional.
  @Gen virtual StatusBool? inReset() { get("inReset") }

  ** The value a reset sets `out` to.  When null a reset sets `yStart`.
  @Gen virtual StatusNumber? inResetVal() { get("inResetVal") }

  ** Integrator gain
  @Gen virtual Number k { get {get("k")} set {set("k", it)} }

  ** The value of `out` at the first execute
  @Gen virtual Number yStart { get {get("yStart")} set {set("yStart", it)} }

  ** `yStart` plus `k` times the integral of `in`
  @Gen virtual StatusNumber? out() { get("out") }

  new make() {}

  ** Has the state been set, by the first valid in or by a reset
  private Bool initialized

  private Float y

  ** Did the last execute take the valid path, so uLast is the input
  ** over the step to this one
  private Bool valid

  private Float uLast

  ** The last valid value of inReset, null before one
  private Bool? resetLast

  ** A reset waiting for a usable inResetVal, and what was integrated
  ** since it fired
  private Bool pending
  private Float acc

  private CycleClock clock := CycleClock()

  override Void onExecute()
  {
    // execute on every cycle: the trapezoid takes the input of the last one
    execute

    // a stall is bounded at its threshold
    dt := CycleClock.sec(clock.bounded(clock.step(cx.now)))
    wasValid := this.valid
    this.valid = false

    kf := k.toFloat
    y0 := yStart.toFloat
    cfgFault := !CycleClock.isFinite(kf) || !CycleClock.isFinite(y0)

    // CDL: when trigger then reinit(y, y_reset_in), read whatever in is
    Status? extra := null
    edge := false
    rs := inReset
    if (rs != null)
    {
      extra = rs.status
      if (rs.status.isValid)
      {
        edge = rs.val && resetLast == false
        this.resetLast = rs.val
      }
    }
    wasPending := pending
    if (edge) { this.pending = true; this.acc = 0f }

    // the value a waiting reset takes, when it is usable on this execute
    Float? resetTo := null
    if (pending && !cfgFault)
    {
      rv := inResetVal
      if (rv == null) resetTo = y0
      else if (rv.status.isValid && CycleClock.isFinite(rv.num.toFloat))
      {
        resetTo = rv.num.toFloat
        extra = extra == null ? rv.status : extra.merge(rv.status)
      }
      else
      {
        // the reset waits; out shows why
        s := rv.status.isValid ? rv.status.set(Status.fault) : rv.status
        extra = extra == null ? s : extra.merge(s)
      }
    }

    // CDL: der(y) = k*u, by the trapezoid.  The step to the edge comes
    // before the reset, and while it waits the steps go to acc.
    u := in
    v := u?.num?.toFloat
    usable := u != null && !cfgFault && u.status.isValid && CycleClock.isFinite(v)
    ny := y
    nacc := acc
    if (usable && initialized && wasValid)
    {
      inc := kf * (uLast + v) / 2f * dt
      if (pending && !edge) nacc += inc
      else if (!wasPending) ny += inc
    }
    if (resetTo != null) { ny = resetTo + nacc; nacc = 0f }

    // an overflow keeps the state and drops the step
    overflow := !CycleClock.isFinite(ny) || !CycleClock.isFinite(nacc)
    if (!overflow)
    {
      this.y = ny
      this.acc = nacc
      if (resetTo != null) { this.initialized = true; this.pending = false }
    }

    if (u == null) return set("out", null)

    status := extra == null ? u.status : u.status.merge(extra)
    held := initialized ? y : y0

    // a configuration fault is checked before the invalid rule
    if (cfgFault) return write(held, status.set(Status.fault))

    // an invalid in holds the value of out, null included
    if (!u.status.isValid)
    {
      if (out != null) write(held, status)
      return
    }

    // a non-finite in with a valid status is a fault
    if (!CycleClock.isFinite(v)) return write(held, status.set(Status.fault))

    // so is an overflow; the next execute steps again from this in, so
    // the fault holds for as long as the overflow does
    if (overflow)
    {
      this.uLast = v
      this.valid = initialized
      return write(held, status.set(Status.fault))
    }

    // CDL: initial equation y = y_start
    if (!initialized) { this.initialized = true; this.y = y0 }
    this.uLast = v
    this.valid = true
    write(y, status)
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
