//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Oct 2026  Lincoln Harmer  Creation
//

**
** The time between executes of a continuous component: `Integrator`,
** `Derivative`, `SlewRateLimit` and `MovingAverage`.  Each component
** executes on every cycle and takes its step from this clock.  A step
** is the time since the last execute, or 0 when the clock did not move
** forward.
**
** A step is a stall when it is longer than both `maxStep` and the
** larger of the component's own time scale and 10 times the reference,
** the longest of its last 8 steps that were not 0.  The own scale is
** the window of `MovingAverage` and the time constant of `Derivative`;
** the others have none.  A stall joins the reference as its threshold,
** not its length.  So after an outage, or a change to a longer cycle,
** only the first long step is a stall (one more per tenfold past the
** threshold), and a second outage within 8 steps is judged against 10
** times the first one's threshold.  A cycle that grows by up to 10
** times at each step, such as a doubling backoff, is never a stall.
** The first step has an empty reference, so it is a stall when longer
** than both `maxStep` and the own scale.
**
** `Integrator` and `SlewRateLimit` bound a stall at its threshold
** (`bounded`), so an outage cannot integrate input the host never saw
** into one jump.  `Derivative` and `MovingAverage` treat it as a gap,
** since a slope or an average over it would be invented.
**
internal class CycleClock
{
  ** The shortest step that can be a stall
  static const Duration maxStep := 1min

  ** The multiple of the reference a step must pass to be a stall
  static const Int noScaleFactor := 10

  ** How many recent steps the reference is the longest of
  static const Int refSteps := 8

  ** Ticks since the last call, 0 on the first call or when the clock did
  ** not move forward, and set `stalled` and `threshold`.  The `scale` is
  ** the component's own time scale in ticks.  This is an `OwnClock`
  ** step; a timer counts a long outage in full, this judges it a stall.
  Int step(DateTime now, Int? scale := null)
  {
    clock.tick(now)
    el := clock.step
    this.threshold = maxStep.ticks.max((scale ?: 0).max(cycleLimit))
    this.stalled = el > threshold
    if (el > 0)
    {
      recent.add(stalled ? threshold : el)
      if (recent.size > refSteps) recent.removeAt(0)
    }
    return el
  }

  ** 10 times the reference, or 0 before any step
  private Int cycleLimit()
  {
    if (recent.isEmpty) return 0
    ref := recent.max
    return ref > Int.maxVal / noScaleFactor ? Int.maxVal : noScaleFactor * ref
  }

  ** The step, or the threshold when it was a stall
  Int bounded(Int el) { stalled ? threshold : el }

  ** Was the last step a stall
  Bool stalled { private set }

  ** The stall threshold of the last step, in ticks
  Int threshold { private set }

  ** Is a float neither NaN nor infinite
  static Bool isFinite(Float f) { !f.isNaN && f != Float.posInf && f != Float.negInf }

  ** Ticks to seconds
  static Float sec(Int ticks) { ticks.toFloat / 1e9f }

  ** Seconds to ticks for a scale: 0 for one not finite or not above 0
  static Int ticks(Float sec)
  {
    if (!isFinite(sec) || !(sec > 0f)) return 0
    t := sec * 1e9f
    return t >= 9.2e18f ? Int.maxVal : t.toInt
  }

  ** The time between calls
  private OwnClock clock := OwnClock()

  ** The last steps that were not 0, oldest first
  private Int[] recent := Int[,]
}
