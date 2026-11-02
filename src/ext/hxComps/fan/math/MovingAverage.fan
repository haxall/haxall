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
** The average of `in` over the last `window` of time, with `in` taken
** as a straight line between executes.  Until a full window has passed,
** the average is over the time since the first execute plus 1E-10
** seconds, as ASHRAE 231 section 7.5.24 gives, so the first execute
** writes 0.  MBL (the Modelica Buildings Library) adds 1E-3 seconds, so
** the first seconds differ slightly.  This is the CDL
** `Reals.MovingAverage` block, with `window` for its `delta`.
**
** Time while `in` is null, invalid or a fault is left out of the
** average, and so is a stall, a step longer than both 1min and the
** larger of `window` and 10 times the longest of the last 8 steps.
** When a full window has no valid time `out` is `in`.  The component
** keeps one entry per execute in the window.  A null `in` sets `out` to
** null, an invalid `in` holds `out` with its status, and a fault holds
** `out` with fault, never null: a `window` below 10 microseconds, an
** `in` that is not finite, or a step that overflows.  `out` has the
** unit of `in`.
**
@Gen
class MovingAverage : HxComp
{
  ** Input to average
  @Gen virtual StatusNumber? in() { get("in") }

  ** Length of time to average over, at least 10 microseconds
  @Gen virtual Duration window { get {get("window")} set {set("window", it)} }

  ** Average of `in` over the window
  @Gen virtual StatusNumber? out() { get("out") }

  new make() {}

  ** Has the first valid in been seen
  private Bool initialized

  ** Did the last execute take the valid path, so the step to this one
  ** is a segment of valid input
  private Bool valid

  private Float y

  ** Component time: the sum of the forward steps of the clock, so a
  ** clock that moves backward cannot reorder the history
  private Int ctime

  ** Component time of the first valid execute, CDL tStart
  private Int start

  ** The history, one entry per valid execute from head on: component
  ** time, the integral and valid time of the segment ending there (0
  ** for a gap), in at the end of it, and in held over the next one
  private Int[] ts := Int[,]
  private Float[] segMus := Float[,]
  private Float[] segTaus := Float[,]
  private Float[] uEnds := Float[,]
  private Float[] uStarts := Float[,]
  private Int head

  ** The integral and valid time of the segments after head, as
  ** compensated sums (Neumaier), so a sum is `sumMu + cMu`
  private Float sumMu
  private Float cMu
  private Float sumTau
  private Float cTau

  ** Segments dropped since the sums were last summed afresh
  private Int dropped

  ** How many times the sums were summed afresh, for the tests
  internal Int resums

  ** Did the last execute that reached the history overflow
  private Bool overflowed

  ** CDL delta(min = 1E-5)
  private static const Duration minWindow := 10_000ns

  ** ASHRAE 231 section 7.5.24 adds 1E-10 seconds to the elapsed time
  ** until the window fills
  private static const Float guard := 1E-10f

  private CycleClock clock := CycleClock()

  override Void onExecute()
  {
    // execute on every cycle: the trapezoid takes the input of the last
    // one
    execute

    // a stall is a gap, so the window does not keep the samples before it
    el := clock.step(cx.now, window.ticks)
    stalled := clock.stalled
    this.ctime += el
    wasValid := this.valid
    this.valid = false

    u := in
    if (u == null) return set("out", null)

    status := u.status
    unit := u.num.unit
    w := window
    held := initialized ? y : 0f

    // a window below the CDL minimum is checked before the invalid rule
    if (w < minWindow) return write(held, unit, status.set(Status.fault))

    // an invalid in holds the value of out, null included
    if (!status.isValid)
    {
      if (out != null) write(held, unit, status)
      return
    }

    // a non-finite in with a valid status is a fault
    v := u.num.toFloat
    if (!CycleClock.isFinite(v)) return write(held, unit, status.set(Status.fault))

    // what this execute changes, to undo if its result is not finite
    size0 := ts.size
    head0 := head
    uStart0 := size0 > 0 ? uStarts[size0 - 1] : 0f
    start0 := start
    sumMu0 := sumMu
    cMu0 := cMu
    sumTau0 := sumTau
    cTau0 := cTau
    dropped0 := dropped

    if (!initialized)
    {
      // CDL: tStart = time, mu = 0
      this.initialized = true
      this.start = ctime
      append(ctime, 0f, 0f, v)
    }
    else
    {
      last := ts.size - 1
      if (ts[last] == ctime)
      {
        // no time has passed: this in is held over the next segment
        uStarts[last] = v
      }
      else if (wasValid && !stalled)
      {
        // CDL: u = der(mu), by the trapezoid.  After an overflow the
        // segment from the input that overflowed is left out like null
        // time: its integral would be an average over a fault
        h := CycleClock.sec(ctime - ts[last])
        seg := (uStarts[last] + v) / 2f * h
        if (overflowed && CycleClock.isFinite(seg)) append(ctime, 0f, 0f, v)
        else append(ctime, seg, h, v)
      }
      else
      {
        // first valid execute after a gap or a stall
        append(ctime, 0f, 0f, v)
      }
    }

    // drop what the window has passed, keeping one entry at or before
    // its start, and the segments that end there from the sums
    from := ctime - w.ticks
    n := 0
    while (head + 1 < ts.size && ts[head + 1] <= from)
    {
      head++
      addMu(-segMus[head])
      addTau(-segTaus[head])
      n++
    }

    // sum afresh once per window's worth of drops, so rounding cannot
    // build up
    last := ts.size - 1
    this.dropped += n
    if (n > 0 && dropped >= last - head) resum

    // the window starts inside the segment after head: take off the
    // part before the start, on the line in takes over it
    Float muDel := 0f
    Float tauDel := 0f
    if (from > ts[head] && head < last)
    {
      a := head
      b := head + 1
      if (segTaus[b] > 0f)
      {
        h := CycleClock.sec(ts[b] - ts[a])
        s := CycleClock.sec(from - ts[a])
        muDel = uStarts[a] * s + (uEnds[b] - uStarts[a]) * s * s / (2f * h)
        tauDel = s
      }
    }
    // CDL: mu - muDel, the integral over the window
    dmu := (sumMu + cMu) - muDel
    dtau := (sumTau + cTau) - tauDel

    // CDL: y = if mode then (mu - muDel)/delta else
    // (mu - muDel)/(time - tStart + 1E-10), here over the valid time
    Float ny := ctime - start < w.ticks ? dmu / (dtau + guard) : (dtau <= 0f ? v : dmu / dtau)

    // an overflow puts the history back as it was and drops the step
    if (!CycleClock.isFinite(sumMu + cMu) || !CycleClock.isFinite(ny))
    {
      if (ts.size > size0) { ts.removeRange(size0..-1); segMus.removeRange(size0..-1); segTaus.removeRange(size0..-1); uEnds.removeRange(size0..-1); uStarts.removeRange(size0..-1) }
      if (size0 > 0) uStarts[size0 - 1] = uStart0
      this.head = head0
      this.start = start0
      this.initialized = size0 > 0
      this.sumMu = sumMu0
      this.cMu = cMu0
      this.sumTau = sumTau0
      this.cTau = cTau0
      this.dropped = dropped0
      // the next segment starts from this in, so the fault holds for as
      // long as the overflow does
      if (size0 > 0)
      {
        if (ts[size0 - 1] == ctime) uStarts[size0 - 1] = v
        else append(ctime, 0f, 0f, v)
        this.valid = true
      }
      this.overflowed = true
      return write(held, unit, status.set(Status.fault))
    }
    this.overflowed = false
    compact
    this.y = ny
    this.valid = true
    write(y, unit, status)
  }

  ** Append an entry to the history, its segment to the sums
  private Void append(Int t, Float mu, Float tau, Float u)
  {
    ts.add(t); segMus.add(mu); segTaus.add(tau); uEnds.add(u); uStarts.add(u)
    addMu(mu)
    addTau(tau)
  }

  ** Sum the segments after head afresh
  private Void resum()
  {
    this.sumMu = 0f; this.cMu = 0f
    this.sumTau = 0f; this.cTau = 0f
    for (i := head + 1; i < ts.size; ++i)
    {
      addMu(segMus[i])
      addTau(segTaus[i])
    }
    this.dropped = 0
    this.resums++
  }

  ** Add x to the integral's compensated sum
  private Void addMu(Float x)
  {
    s := sumMu
    t := s + x
    if (s.abs >= x.abs) this.cMu += (s - t) + x
    else this.cMu += (x - t) + s
    this.sumMu = t
  }

  ** Add x to the valid time's compensated sum, as `addMu`
  private Void addTau(Float x)
  {
    s := sumTau
    t := s + x
    if (s.abs >= x.abs) this.cTau += (s - t) + x
    else this.cTau += (x - t) + s
    this.sumTau = t
  }

  ** Remove the dropped entries once they are half the history
  private Void compact()
  {
    if (head < 1024 || head * 2 < ts.size) return
    ts.removeRange(0..<head)
    segMus.removeRange(0..<head)
    segTaus.removeRange(0..<head)
    uEnds.removeRange(0..<head)
    uStarts.removeRange(0..<head)
    this.head = 0
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
