//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Oct 2026  Lincoln Harmer  Creation
//

**
** A component's own clock, for a timed component whose deadlines must
** survive a step of the host clock backward.  Each `tick` adds the time
** since the last one, or nothing when the host clock did not move
** forward.  So a step back counts as no time, but the time between the
** ticks either side of it is lost too, up to the size of the step.  Only
** tick differences are taken, so no DateTime is built.
**
** The clock is `behind` while the host clock is behind the latest time it
** has seen.  A component then executes every cycle, by calling `execute`
** from `onExecute`, and returns its idle rate from `onExecuteFreq`.  It
** ticks every cycle, so a further step back while behind loses at most one
** cycle rather than the time to the next timer execute.  After a jump to a
** far future time and back, `behind` lasts until the host clock reaches
** that time again.
**
internal class OwnClock
{
  ** Advance to the host clock `now` and return the own clock, in ticks
  Int tick(DateTime now)
  {
    t := now.ticks
    if (lastNow == null) { this.ticks = t; this.maxNow = t; this.step = 0 }
    else { this.step = t > lastNow ? t - lastNow : 0; this.ticks += step }
    this.lastNow = t
    this.behind = t < maxNow
    if (!behind) this.maxNow = t
    return ticks
  }

  ** The own clock at the last tick, in ticks
  Int ticks { private set }

  ** Ticks the last tick added, 0 if the host clock did not move forward
  Int step { private set }

  ** Has the clock been ticked
  Bool started() { lastNow != null }

  ** Was the host clock, at the last tick, behind the latest one seen
  Bool behind { private set }

  private Int? lastNow

  ** The latest host clock seen
  private Int maxNow
}
