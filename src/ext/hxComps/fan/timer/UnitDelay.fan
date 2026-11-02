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
** Outputs `in` as it was at the previous instant, so `out` is `yStart`
** until the second instant.  This is the CDL `Discrete.UnitDelay` block.
** The instants are those of `SampledComp`.  The component captures `in`
** on the cycle after an instant and emits it at the next.
**
** The link into `in` should carry a `loopCut` marker, in a loop or not.
** A cut link delivers at the end of a cycle, so the capture reads what
** the linked component computed on the instant's cycle in any order.
** Uncut, an open chain captures `in` one cycle late, and a loop through
** the component depends on creation order.  The null and status rules
** are the cut rule of `SampledComp`, cut or not: a null, invalid or NaN
** `in` keeps the last capture, or `yStart` before the first, and `out`
** is `ok`, or `fault` with the held value and no capture for a `period`
** below 1ms.  The state is not persisted.
**
@Gen
class UnitDelay : HxComp
{
  ** Input to delay
  @Gen virtual StatusNumber? in() { get("in") }

  ** Time between instants.  It must be at least 1ms.
  @Gen virtual Duration period { get {get("period")} set {set("period", it)} }

  ** Value of out until the first value captured from in is emitted
  @Gen virtual Number yStart { get {get("yStart")} set {set("yStart", it)} }

  ** Output
  @Gen virtual StatusNumber? out() { get("out") }

  new make()
  {
  }

  ** Instants passed over by a late execute
  @NoDoc Int skipped { private set }

  ** Captures that kept the register because in was null, invalid or NaN
  @NoDoc Int held { private set }

  ** u_internal, valid once hasCaptured; before that the register is yStart
  private Number captured := Number.zero
  private Bool hasCaptured

  ** The value out emits, valid once emitted; before that out is yStart
  private Number emitVal := Number.zero
  private Bool emitted

  ** The instant's execute schedules a capture of in on the next execute
  private Bool capturePending

  private HoldLog holdLog := HoldLog()

  private SampleClock clock := SampleClock()

  ** CDL samplePeriod(min = 1E-3)
  private static const Duration minPeriod := 1ms

  override Duration? onExecuteFreq()
  {
    // timed comps are collected when mounted, so never return null
    clock.started ? clock.left : SampleClock.idleFreq
  }

  override Void onExecute()
  {
    now := cx.now
    p := period

    if (p < minPeriod)
    {
      clock.stop
      capturePending = false
      return write(emitting, Status.fault)
    }

    // the capture the last instant scheduled: under a loopCut link, in
    // holds what the linked component computed on the instant's cycle
    if (capturePending)
    {
      capturePending = false
      u := in
      if (u != null && u.status.isValid && !u.num.isNaN)
      {
        captured = u.num
        hasCaptured = true
        holdLog.ok(this)
      }
      else
      {
        held++
        holdLog.held(this, u, hasCaptured ? captured : yStart)
      }
    }

    // CDL: when sampleTrigger then y = pre(u_internal)
    n := clock.advance(now, p.ticks, 0)
    if (n > 1) skipped += n - 1
    if (n > 0)
    {
      if (hasCaptured) { emitVal = captured; emitted = true }
      capturePending = true
      execute
    }
    write(emitting, Status.ok)
  }

  ** The register as of the last instant, or yStart before an emit
  private Number emitting() { emitted ? emitVal : yStart }

  ** Write out only on a change
  private Void write(Number v, Status status)
  {
    o := out
    if (o != null && o.num == v && o.status == status) return
    set("out", StatusNumber(v, status))
  }
}
