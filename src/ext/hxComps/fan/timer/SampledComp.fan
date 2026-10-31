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
** The base spec for components that sample `in` at instants a whole
** number of `period`s after 1 Jan 1970 UTC, the instants of a
** `SampleTrigger` with the same `period` and no `shift`.  An instant
** takes effect on the first execute at or after it, with the value of
** `in` on that execute.  A late cycle that passes several instants
** samples once, an instant fires once, even when the clock moves
** backward, and a change of `period` restarts the clock.  The state is
** not persisted.
**
** A null `in` sets `out` to null.  An invalid `in` holds the value of
** `out`, with the status of `in`.  A NaN `in` with a valid status, or a
** `period` below 1ms, is a fault: `out` holds its value, or takes `in`
** before the first sample, with the status of `in` plus fault.  An
** instant that passes while `in` is null, invalid or a fault takes no
** sample.
**
@Gen
abstract class SampledComp : HxComp
{
  ** Input to sample
  @Gen virtual StatusNumber? in() { get("in") }

  ** Time between instants.  It must be at least 1ms.
  @Gen virtual Duration period { get {get("period")} set {set("period", it)} }

  ** Output
  @Gen virtual StatusNumber? out() { get("out") }

  ** Instants passed over by a late execute
  @NoDoc Int skipped { private set }

  ** Has the first valid in been seen
  private Bool initialized

  ** Did the last execute take the valid path
  private Bool valid

  private SampleClock clock := SampleClock()

  ** CDL samplePeriod(min = 1E-3)
  private static const Duration minPeriod := 1ms

  ** Refresh between instants while out moves, as Timer does
  private static const Duration refreshFreq := 1sec

  override Duration? onExecuteFreq()
  {
    // timed comps are collected when mounted, so never return null
    if (!clock.started) return SampleClock.idleFreq
    left := clock.left
    return valid && moving ? left.min(refreshFreq) : left
  }

  override Void onExecute()
  {
    now := cx.now
    p := period
    bad := p < minPeriod

    // the clock runs whatever in is
    fired := false
    if (initialized)
    {
      if (bad) clock.stop
      else
      {
        n := clock.advance(now, p.ticks, 0)
        if (clock.restarted) restart(now, valid)
        if (n > 1) skipped += n - 1
        fired = n > 0
      }
    }
    this.valid = false

    u := in
    if (u == null)
    {
      if (fired) pass(now, clock.ago)
      return set("out", null)
    }

    // a bad period is a fault, checked before the invalid rule
    status := u.status
    if (bad) return write(held(u), status.set(Status.fault))

    // before the first value, out is a value a fault wrote
    if (!status.isValid)
    {
      if (fired) pass(now, clock.ago)
      o := out
      if (o != null) write(initialized ? heldVal : o.num, status)
      return
    }

    if (u.num.isNaN)
    {
      if (fired) pass(now, clock.ago)
      return write(held(u), status.set(Status.fault))
    }

    if (!initialized)
    {
      // CDL initial equations, and an instant exactly at now is due
      this.initialized = true
      init(u, now)
      fired = clock.advance(now, p.ticks, 0) > 0
    }

    // CDL: when sampleTrigger then ...
    if (fired) sample(u, now, p.ticks, clock.ago)
    this.valid = true
    write(update(now), outStatus)
  }

  ** The value out holds while in is not valid
  private Number held(StatusNumber u) { initialized ? heldVal : u.num }

  ** Write out only on a change, which keeps a loop quiet between instants
  private Void write(Number v, Status status)
  {
    o := out
    if (o != null && o.num == v && o.status == status) return
    set("out", StatusNumber(v, status))
  }

//////////////////////////////////////////////////////////////////////////
// Zero order hold: Sampler and ZeroOrderHold
//////////////////////////////////////////////////////////////////////////

  ** CDL initial equations, at the first valid in; default y = u
  protected virtual Void init(StatusNumber u, DateTime now) { sample(u, now, 0, 0) }

  ** CDL when sampleTrigger, ago ticks after the instant; default y = u
  protected virtual Void sample(StatusNumber u, DateTime now, Int period, Int ago)
  {
    this.sampleVal = u.num
    this.sampleStatus = u.status
  }

  ** An instant passed with no valid in; by default the sample is kept
  protected virtual Void pass(DateTime now, Int ago) {}

  ** The clock restarted on a new period; live if the last execute was valid
  protected virtual Void restart(DateTime now, Bool live) {}

  ** Does out change between instants
  protected virtual Bool moving() { false }

  ** Value of out on a valid execute at now
  protected virtual Number update(DateTime now) { sampleVal }

  ** Value of out while in is null, invalid or a fault
  protected virtual Number heldVal() { sampleVal }

  ** Status of out on a valid execute
  protected virtual Status outStatus() { sampleStatus }

  ** Zero order hold: the last sample and the status in had then
  private Number sampleVal := Number.zero
  private Status sampleStatus := Status.ok
}

**
** Samples `in` at each instant and holds the sample until the next one,
** with the status `in` had then.  This is the CDL `Discrete.Sampler`
** block.  It has direct feedthrough.
**
@Gen
class Sampler : SampledComp
{
}

**
** Holds `in` from one instant to the next, with the status `in` had at
** the instant.  This is the CDL `Discrete.ZeroOrderHold` block.  In an
** open chain `out` is the same as for `Sampler`.
**
** It has no direct feedthrough in CDL, `y = pre(ySample)`, but it does
** not cut a loop: `out` is null before the first sample, so a loop
** through it starts only if another component in it gives a value from
** a null input, as `Add` does.
**
@Gen
class ZeroOrderHold : SampledComp
{
}
