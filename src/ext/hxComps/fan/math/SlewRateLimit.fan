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
** Limits the rate at which `out` follows `in`.  `out` approaches `in`
** at the rate `(in - out) / timeConst`, held between `fallingSlewRate`
** and `raisingSlewRate`.  While `enable` is false `out` is `in`.  This
** is the CDL `Reals.LimitSlewRate` block, and the CDL `Reals.Ramp` block
** with `active` linked to `enable` through a `StatusBoolToBool` and
** `timeConst` set to `raisingSlewRate` times 0.001 seconds.
**
** Unlike CDL, each step is a backward Euler step to the current `in`,
** so `out` has direct feedthrough from `in`.  A stall, a step longer
** than both 1min and 10 times the longest of the last 8 steps, counts
** as the larger of the two.  A null `in` sets `out` to null, an invalid
** `in` holds `out` with its status, and a fault holds `out` with fault,
** never null: a `raisingSlewRate` not above 0, a `fallingSlewRate` not
** below 0, either rate not finite or with a unit that does not fit
** `in`, a `timeConst` not above 0, an `in` that is not finite, or a
** step that overflows.  `out` has the unit of `in`.
**
@Gen
class SlewRateLimit : HxComp
{
  ** Input to follow
  @Gen virtual StatusNumber? in() { get("in") }

  ** Fastest increase of `out`, in units of `in` per second, or in the
  ** unit of `in` per the time unit it carries.  It must be above 0.
  @Gen virtual Number raisingSlewRate { get {get("raisingSlewRate")} set {set("raisingSlewRate", it)} }

  ** Fastest decrease of `out`, in the units of `raisingSlewRate`.  It
  ** must be below 0.  When null it is minus `raisingSlewRate`.
  @Gen virtual Number? fallingSlewRate { get {get("fallingSlewRate")} set {set("fallingSlewRate", it)} }

  ** Time constant of the approach to `in`, above 0.  When null it is
  ** `raisingSlewRate`, per second, times 10 seconds, the CDL default.
  @Gen virtual Duration? timeConst { get {get("timeConst")} set {set("timeConst", it)} }

  ** When false `out` is `in`
  @Gen virtual Bool enable { get {get("enable")} set {set("enable", it)} }

  ** `in`, rate limited
  @Gen virtual StatusNumber? out() { get("out") }

  new make() {}

  ** Has the first valid in been seen
  private Bool initialized

  ** Did the last execute take the valid path
  private Bool valid

  ** The state y, and enable at the last valid execute
  private Float y
  private Bool enableLast

  private CycleClock clock := CycleClock()

  override Void onExecute()
  {
    // execute on every cycle: each step is the time since the last one
    execute

    // a stall is bounded at its threshold
    dt := CycleClock.sec(clock.bounded(clock.step(cx.now)))
    wasValid := this.valid
    this.valid = false

    u := in
    if (u == null) return set("out", null)

    status := u.status
    unit := u.num.unit
    r := perSec(raisingSlewRate, unit) ?: Float.nan
    fs := fallingSlewRate
    f := fs == null ? -r : (perSec(fs, unit) ?: Float.nan)
    tc := timeConst
    td := tc == null ? r * 10f : CycleClock.sec(tc.ticks)
    held := initialized ? y : u.num.toFloat

    // configuration faults, checked before the invalid rule.  A rate with
    // the wrong unit is NaN here, which fails each compare.
    if (!(r > 0f) || !(f < 0f) || !(td > 0f) || !CycleClock.isFinite(r) || !CycleClock.isFinite(f))
      return write(held, unit, status.set(Status.fault))

    // an invalid in holds the value of out, null included
    if (!status.isValid)
    {
      if (out != null) write(held, unit, status)
      return
    }

    // a non-finite in with a valid status is a fault
    v := u.num.toFloat
    if (!CycleClock.isFinite(v)) return write(held, unit, status.set(Status.fault))

    en := enable
    ny := y
    if (!initialized || !en || !enableLast)
    {
      // CDL: initial equation y = u; with enable false y = u; Ramp: when
      // active then reinit(y_internal, u)
      ny = v
    }
    else if (wasValid && dt > 0f)
    {
      // CDL: der(y) = clamp((u - y)/Td, fallingSlewRate, raisingSlewRate),
      // by backward Euler; past a limit, the step at the limit solves it
      cand := (td * y + dt * v) / (td + dt)
      rate := (cand - y) / dt
      if (rate > r) ny = y + r * dt
      else if (rate < f) ny = y + f * dt
      else ny = cand
    }

    // an overflow keeps the state and is stepped again next execute, so
    // the fault holds for as long as the overflow does
    if (!CycleClock.isFinite(ny))
    {
      this.valid = true
      return write(held, unit, status.set(Status.fault))
    }
    this.y = ny
    this.initialized = true
    this.enableLast = en
    this.valid = true
    write(y, unit, status)
  }

  ** A slew rate in units of `in` per second, or null when its unit is
  ** not the unit of `in` per a time.  For a dimensionless `in` the rate's
  ** own scale is its time factor, since `%/s` has the scale 1 where `%`
  ** has 0.01.
  internal static Float? perSec(Number n, Unit? iu)
  {
    ru := n.unit
    if (ru == null) return n.toFloat
    if (ru.offset != 0f) return null
    if (ru.kg != (iu?.kg ?: 0) || ru.m != (iu?.m ?: 0) || ru.sec != (iu?.sec ?: 0) - 1 ||
        ru.K != (iu?.K ?: 0) || ru.A != (iu?.A ?: 0) || ru.mol != (iu?.mol ?: 0) || ru.cd != (iu?.cd ?: 0))
      return null
    dimensionless := iu == null || (iu.kg == 0 && iu.m == 0 && iu.sec == 0 && iu.K == 0 && iu.A == 0 && iu.mol == 0 && iu.cd == 0)
    return dimensionless ? n.toFloat * ru.scale : n.toFloat * ru.scale / iu.scale
  }

  ** Write out unless it already has this value and status.  A value
  ** that is not finite is written as NaN with fault.
  private Void write(Float v, Unit? unit, Status status)
  {
    if (!CycleClock.isFinite(v)) { v = Float.nan; status = status.set(Status.fault) }
    o := out
    n := Number(v, unit)
    if (o != null && o.num == n && o.status == status) return
    set("out", StatusNumber(n, status))
  }
}
