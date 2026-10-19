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
** Generates a pulse train.  `out` turns true at `shift` plus each whole
** `period` after 1 Jan 1970 UTC, and false `width` times `period` later.
** The rises fall on the instants of a `SampleTrigger` with the same
** `period` and `shift`.  The grid is UTC, so a `period` of 1day rises at
** 00:00 UTC plus `shift`.  This is the CDL `Logical.Sources.Pulse` block.
**
** Each execute sets `out` from where the clock falls in the period, so a
** pulse or a gap not longer than the time between executes can be missed.
** A `period` of 0 or less, or a `width` of 0 or less, above 1 or NaN, is
** a fault, and `out` is false with status fault.  For the CDL
** `Reals.Sources.Pulse` and `Integers.Sources.Pulse` blocks, link `out`
** to the `inSwitch` of a `NumberSwitch` whose `inFalse` is `offset` and
** whose `inTrue` is `offset` plus `amplitude`.
**
@Gen
class BoolPulse : HxComp
{
  ** Fraction of each period that `out` is true, more than 0 and at most 1
  @Gen virtual Float width { get {get("width")} set {set("width", it)} }

  ** Time from one rise to the next, more than 0
  @Gen virtual Duration period { get {get("period")} set {set("period", it)} }

  ** Offset of the rises.  Only `mod(shift, period)` counts.
  @Gen virtual Duration shift { get {get("shift")} set {set("shift", it)} }

  ** True for `width` of each period
  @Gen virtual StatusBool? out() { get("out") }

  new make()
  {
  }

  ** True and false windows that no execute landed in
  @NoDoc Int skipped { private set }

  private SampleClock rises := SampleClock()

  ** The falls; stopped at a width of 1, which has none
  private SampleClock falls := SampleClock()

  override Duration? onExecuteFreq()
  {
    // timed comps are collected when mounted, so never return null
    if (!rises.started) return SampleClock.idleFreq
    left := rises.left
    return falls.started ? left.min(falls.left) : left
  }

  override Void onExecute()
  {
    now := cx.now

    // a NaN width fails the compare, so it faults too
    p := period.ticks
    w := width
    if (p <= 0 || !(w > 0f && w <= 1f))
    {
      rises.stop
      falls.stop
      return write(false, Status.fault)
    }

    // CDL: t0 = integer(time/period)*period + mod(shift, period)
    offset := SampleClock.offsetOf(shift, p)
    n := rises.advance(now, p, offset)
    restarted := rises.restarted

    // as of the latest time seen, so a clock that moves back holds out
    phase := p - rises.left.ticks

    // a width of 1 has no falls: CDL gives the rise priority over the fall
    wt := (w * p.toFloat).round.toInt
    if (w >= 1f || wt >= p)
    {
      falls.stop
      return write(true, Status.ok)
    }

    // offset + wt mod p, without overflowing 2p
    fallOffset := wt < p - offset ? offset + wt : wt - (p - offset)
    f := falls.advance(now, p, fallOffset)
    restarted = restarted || falls.restarted

    // CDL's initial algorithm and its two when clauses both reduce to this
    v := phase < wt

    // windows passed unseen; a restart has no earlier execute to compare
    if (!restarted) skipped += (n - (v ? 1 : 0)).max(0) + (f - (v ? 0 : 1)).max(0)

    write(v, Status.ok)
  }

  ** Write out when its value or status changes
  private Void write(Bool v, Status status)
  {
    o := out
    if (o != null && o.val == v && o.status == status) return
    set("out", StatusBool(v, status))
  }
}
