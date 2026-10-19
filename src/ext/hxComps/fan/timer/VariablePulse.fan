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
** Generates a pulse train whose width follows `in`.  The periods run
** from the first execute at the run period, the larger of `period` and
** 2.02 times `minHold`.  `out` is true from the start of each period for
** `in` times the run period, and false for the rest.  The periods start
** again when `in` moves more than `deltaU` from its value when they last
** started.  At the first execute that value is `in`, or 0 when `in` is
** within `deltaU` of 0.  A smaller move changes the width within the
** running period.  A change of `out` waits until `out` has kept its value
** for `minHold`, counted from the first execute and from each change, and
** is dropped if the pulse has turned back by then.  This is the CDL
** `Logical.VariablePulse` block.
**
** A `period` under 2 times `minHold` logs a warning once to the `hxComps`
** log, as CDL does.  A change of `period`, or of `minHold` that changes
** the run period, starts the periods again without restarting the hold.
** A null `in` sets `out` to null.  An invalid `in` holds `out`, a null
** included, with the status of `in`.  A `deltaU` outside 0.001 to 0.5, a
** `minHold` of 0 or less, a `period` of 0 or less with a null `minHold`
** and a run period under 1ms are faults, even with an invalid `in`, and
** so is a NaN `in` with a valid status.  A fault holds `out`, false
** before the first value, with the status of `in` plus fault.  A null or
** invalid `in` and a fault each keep the state.  The periods and the hold
** run on the component's own clock, and edges between executes apply in
** order at the next one.  A step of the clock backward counts as no time,
** but the time between the executes either side of it is lost too, up to
** the size of the step.  While the host clock is behind the latest time it
** has seen, the component executes every cycle.
**
@Gen
class VariablePulse : HxComp
{
  ** The fraction of each period that `out` is true, from 0 to 1
  @Gen virtual StatusNumber? in() { get("in") }

  ** Time from one rise to the next
  @Gen virtual Duration period { get {get("period")} set {set("period", it)} }

  ** How far `in` must move to start the periods again, 0.001 to 0.5
  @Gen virtual Float deltaU { get {get("deltaU")} set {set("deltaU", it)} }

  ** Minimum time `out` keeps each value, 0.01 times `period` when null
  @Gen virtual Duration? minHold { get {get("minHold")} set {set("minHold", it)} }

  ** The pulse
  @Gen virtual StatusBool? out() { get("out") }

  new make()
  {
  }

  ** Skip whole periods once their start state repeats, off only in tests
  @NoDoc Bool fastForward := true

  ** Periods a walk may pass with no repeat before it warns, for tests
  @NoDoc Int noRepeat := 300

  private Bool initialized

  ** in at the last valid execute
  private Float inVal

  ** The value a move of in is measured from
  private Float sampled

  ** Clock ticks when the periods last started
  private Int start

  ** The run period and the hold in ticks
  private Int periodTicks
  private Int holdTicks

  ** The value of out
  private Bool outVal

  ** Clock ticks when out last changed, or the first execute before that
  private Int heldAt

  ** The component's own clock at the last valid execute
  private Int? lastEval

  private OwnClock clock := OwnClock()

  ** Whether the period was short at the last check
  private Bool warned

  ** Whether a walk has logged that it passed noRepeat periods
  private Bool walkWarned

  ** Frequency while nothing is due
  private static const Duration idleFreq := 1min

  ** The shortest period CDL may run at, as for SampledComp
  private static const Int minPeriod := 1ms.ticks

  private static const Log log := Log.get("hxComps")

  override Duration? onExecuteFreq()
  {
    // never null, since timed comps are collected when mounted.  While
    // the clock is behind, onExecute asks for every cycle itself.
    if (!initialized || lastEval == null || !clock.started || clock.behind) return idleFreq
    left := untilNext(lastEval)
    if (left == null) return idleFreq
    left -= clock.ticks - lastEval
    return left > 0 ? Duration(left) : idleFreq
  }

  override Void onExecute()
  {
    // while the clock is behind the latest time seen, ask for every cycle
    clock.tick(cx.now)
    if (clock.behind) execute

    // a null in sets out to null and keeps the state
    u := in
    if (u == null) return set("out", null)
    status := u.status

    // configuration faults, before the invalid rule.  A NaN deltaU fails
    // the compares.  A run period below 1ms, as in SampledComp, would
    // walk a thousand periods or more every second.
    p := period.ticks
    mh := minHold
    m := mh != null ? mh.ticks : (0.01f * p.toFloat).round.toInt
    du := deltaU
    pe := p.max((m.toFloat * 2.02f).round.toInt)
    if (m <= 0 || !(du >= 0.001f && du <= 0.5f) || pe < minPeriod) return write(held, status.set(Status.fault))

    // an invalid in holds the state and the value of out, null included
    if (!status.isValid)
    {
      o := out
      if (initialized && o != null) write(o.val, status)
      return
    }

    // a NaN in with a valid status is a fault
    if (u.num.isNaN) return write(held, status.set(Status.fault))
    x := u.num.toFloat

    // a period under 2 times the hold warns, as CDL does
    checkPeriod(p, m, pe)

    t := clock.ticks

    if (!initialized)
    {
      // the first execute starts the periods.  The value a move is
      // measured from is in, or 0 when in is within deltaU of 0.
      this.initialized = true
      this.inVal = x
      this.sampled = 0f
      this.start = t
      this.periodTicks = pe
      this.holdTicks = m
      if ((x - sampled).abs > du) this.sampled = x
      this.outVal = cycle(t)
      this.heldAt = t
    }
    else
    {
      // apply the edges and hold ends since the last execute, in order
      walk(lastEval, t)

      // a new hold applies from t.  A new period starts the periods
      // again, as a move of in does.
      this.holdTicks = m
      if (pe != periodTicks)
      {
        this.periodTicks = pe
        this.start = t
        this.sampled = x
      }

      // a move of in by more than deltaU starts the periods again, and the
      // next move is measured from its new value
      this.inVal = x
      if ((x - sampled).abs > du)
      {
        this.start = t
        this.sampled = x
      }
      hold(t)
    }
    this.lastEval = t
    write(outVal, status)
  }

  ** Apply every edge and hold end after from and before to, in order.
  ** With in held, each period maps the state at its start (out, and its
  ** age up to the hold) the same way, so once that state repeats at two
  ** period starts in a row the whole periods left are skipped.  The
  ** repeat is expected within a few periods but not proven, so a walk
  ** that passes noRepeat periods without one warns once and walks on.
  private Void walk(Int from, Int to)
  {
    w := inVal * periodTicks.toFloat
    cycling := fastForward && w > 0f && w < periodTicks.toFloat
    Bool? lastOut := null
    lastAge := 0
    periods := 0
    cur := from
    while (true)
    {
      left := untilNext(cur)
      if (left == null || left >= to - cur) break
      cur += left
      hold(cur)

      // at a period start, compare the state with the last one
      if (!cycling || (cur - start) % periodTicks != 0) continue
      age := (cur - heldAt).min(holdTicks)
      if (lastOut == outVal && lastAge == age)
      {
        // the whole periods n with cur + n * period before to
        n := (to - 1 - cur) / periodTicks
        moved := heldAt > cur - periodTicks
        cur += n * periodTicks
        if (moved) this.heldAt += n * periodTicks
        lastOut = null
        periods = 0
        continue
      }
      lastOut = outVal
      lastAge = age
      if (++periods == noRepeat && !walkWarned) warnNoRepeat(cur, to)
    }
  }

  ** Log once, with what it takes to reproduce, that a walk passed
  ** noRepeat periods with no repeat
  private Void warnNoRepeat(Int cur, Int to)
  {
    this.walkWarned = true
    log.warn("${spec.name} @${id}: a walk passed $noRepeat periods without its state at a period start repeating, so it walks on period by period; in $inVal, period ${Duration(periodTicks)}, minHold ${Duration(holdTicks)}, out $outVal held for ${Duration(cur - heldAt)}, ${Duration(to - cur)} left to walk")
  }

  ** The pulse before the hold at clock ticks t: true for the first in
  ** times the run period of each period
  private Bool cycle(Int t)
  {
    phase := (t - start) % periodTicks
    return phase.toFloat < inVal * periodTicks.toFloat
  }

  ** Apply the hold at clock ticks t: out takes the pulse's value once it
  ** has kept its own for the hold, the same for true and false
  private Void hold(Int t)
  {
    c := cycle(t)
    if (c != outVal && t - heldAt >= holdTicks)
    {
      this.outVal = c
      this.heldAt = t
    }
  }

  ** Ticks from a to the next edge or hold end, or null if none is coming
  private Int? untilNext(Int a)
  {
    Int? best := null
    w := inVal * periodTicks.toFloat
    if (w > 0f && w < periodTicks.toFloat)
    {
      // the fall is the first tick whose phase is not less than w
      phase := (a - start) % periodTicks
      fall := w.ceil.toInt
      best = phase < fall ? fall - phase : periodTicks - phase
    }
    h := holdTicks - (a - heldAt)
    if (h > 0 && (best == null || h < best)) best = h
    return best
  }

  ** Warn once each time period drops below 2 times the hold, as CDL does
  private Void checkPeriod(Int p, Int m, Int pe)
  {
    short := p < 2 * m
    if (short && !warned)
      log.warn("${spec.name} @${id}: period ${period} is less than 2 times minHold ${Duration(m)}; CDL warns and runs the periods at ${Duration(pe)}")
    this.warned = short
  }

  ** The value out holds through a fault: false before the first value
  private Bool held() { initialized ? outVal : false }

  ** Write out when its value or status changes
  private Void write(Bool v, Status status)
  {
    o := out
    if (o != null && o.val == v && o.status == status) return
    set("out", StatusBool(v, status))
  }
}
