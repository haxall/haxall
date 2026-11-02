//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using util
using xeto
using haystack

**
** Pulses at each sample instant: `out` is true for one execute at each
** instant and false otherwise.  The instants are `shift` plus a whole
** number of `period`s after 1 Jan 1970 UTC, so components with the same
** `period` and `shift` pulse on the same cycle, and a `period` of 1day
** pulses at 00:00 UTC.  This is the CDL `Logical.Sources.SampleTrigger`
** block.
**
** An instant takes effect on the first execute at or after it, the first
** execute included, and fires once, even when the clock moves backward.
** A late cycle that passes several instants pulses once.  Instants on
** consecutive cycles keep `out` true, writing a new value each time, so a
** component that acts when its input turns true, as `Toggle` does, sees
** one rise for them.  Such runs log a warning to the `hxComps` log at
** most hourly.  A `period` of 0 or less is a fault: `out` is false with
** status fault.
**
@Gen
class SampleTrigger : HxComp
{
  ** Time between instants.  It must be more than 0.
  @Gen virtual Duration period { get {get("period")} set {set("period", it)} }

  ** Offset of the instants.  Only `mod(shift, period)` counts.
  @Gen virtual Duration shift { get {get("shift")} set {set("shift", it)} }

  ** True for one execute at each instant
  @Gen virtual StatusBool? out() { get("out") }

  new make()
  {
  }

  ** Instants passed over by a late execute
  @NoDoc Int skipped { private set }

  private SampleClock clock := SampleClock()

  override Duration? onExecuteFreq()
  {
    // timed comps are collected when mounted, so never return null
    clock.started ? clock.left : SampleClock.idleFreq
  }

  override Void onExecute()
  {
    now := cx.now

    // CDL: period(final min = Constants.small)
    p := period.ticks
    if (p <= 0)
    {
      clock.stop
      track(now, false)
      return write(false, Status.fault)
    }

    // CDL: y = sample(t0, period)
    n := clock.advance(now, p, SampleClock.offsetOf(shift, p))
    if (n > 1) skipped += n - 1
    track(now, n > 0)
    write(n > 0, Status.ok)

    // a pulse lasts one execute: run the next cycle to clear it
    if (n > 0) execute
  }

  ** Log a run of fires on consecutive executes, at most one warning per
  ** logEvery, with a count of the runs it held back
  private Void track(DateTime now, Bool fired)
  {
    if (fired && lastFired)
    {
      if (runFires == 1) onset(now)
      else if (!runLogged && windowOpen(now)) { unlogged--; onset(now) }
      runFires++
    }
    else
    {
      if (runFires > 1 && runLogged)
        log.info("SampleTrigger @${id}: consecutive fires ended after $runFires fires")
      this.runFires = fired ? 1 : 0
      this.runLogged = false
    }
    this.lastFired = fired
  }

  private Void onset(DateTime now)
  {
    if (!windowOpen(now))
    {
      unlogged++
      return
    }
    note := unlogged > 0 ? "; $unlogged runs not logged since the last line" : ""
    log.warn("SampleTrigger @${id}: fires on consecutive cycles, so a component that acts when out turns true sees one rise for them (period at or below the cycle, or a late cycle; logged at most once per $logEvery$note)")
    this.lastLog = now
    this.unlogged = 0
    this.runLogged = true
  }

  ** Has logEvery passed since the last warning, or the clock moved back
  private Bool windowOpen(DateTime now)
  {
    lastLog == null || now - lastLog >= logEvery || now < lastLog
  }

  ** At most one warning per this long
  private static const Duration logEvery := 1hr

  private static const Log log := Log.get("hxComps")

  private Bool lastFired

  private Int runFires

  private Bool runLogged

  ** Time of the last warning, and runs not logged since
  private DateTime? lastLog
  private Int unlogged

  ** Write out.  A true is always a new value, so a linked component
  ** executes on every instant.  A false is written only on a change.
  private Void write(Bool v, Status status)
  {
    o := out
    if (!v && o != null && !o.val && o.status == status) return
    set("out", StatusBool(v, status))
  }
}
