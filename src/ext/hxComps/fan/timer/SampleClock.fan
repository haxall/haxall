//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

**
** The sample instants of SampleTrigger and SampledComp: the points
** m*period + mod(shift, period) of a grid fixed by the UTC epoch,
** from the first at or after the start.  All arithmetic is on Int ticks,
** so no DateTime is built from a period and no Int overflows.
**
internal class SampleClock
{
  ** Has the clock been started, and on which grid
  Bool started() { period > 0 }

  ** Stop the clock; the next advance starts it again
  Void stop() { period = 0 }

  ** Return the number of instants after the last time processed and at
  ** or before now, with 0 <= offset < period in ticks.  A new period or
  ** offset restarts the clock at now.  A clock moved back fires none.
  Int advance(DateTime now, Int period, Int offset)
  {
    t := now.ticks + epochOffset
    this.restarted = period != this.period || offset != this.offset
    if (restarted)
    {
      this.period = period
      this.offset = offset
      this.last   = t - 1
    }
    if (t <= last) return 0
    n := index(t) - index(last)
    this.last = t
    if (n > 0) this.ago = phase(t)
    return n
  }

  ** Ticks from the latest instant fired to the execute that fired it
  Int ago { private set }

  ** Did the last advance (re)start the clock
  Bool restarted { private set }

  ** Time from the last time processed to the next instant, in (0, period]
  Duration left() { Duration(period - phase(last)) }

  ** Ticks since the latest grid point at or before t, in [0, period)
  private Int phase(Int t)
  {
    p := floorMod(t, period) - offset
    return p < 0 ? p + period : p
  }

  ** Index of the latest grid point at or before t
  private Int index(Int t)
  {
    floorDiv(t, period) - (floorMod(t, period) < offset ? 1 : 0)
  }

  private static Int floorDiv(Int a, Int b)
  {
    q := a / b
    return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
  }

  private static Int floorMod(Int a, Int b)
  {
    m := a % b
    return m < 0 ? m + b : m
  }

  ** Offset in ticks of a shift on the grid of period: mod(shift, period)
  static Int offsetOf(Duration shift, Int period) { floorMod(shift.ticks, period) }

  ** Ticks from 1 Jan 1970 UTC to 1 Jan 2000 UTC, the DateTime epoch
  static const Int epochOffset := 946_684_800_000_000_000

  ** Frequency while stopped: a timed comp must never return null
  static const Duration idleFreq := 1min

  private Int period
  private Int offset
  private Int last
}
