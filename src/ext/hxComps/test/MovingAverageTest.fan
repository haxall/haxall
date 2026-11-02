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
** MovingAverage: the CDL Reals.MovingAverage block
**
class MovingAverageTest : ContinuousCompTest
{
  MovingAverage newComp(Duration w)
  {
    c := (MovingAverage)createComp("MovingAverage")
    c.window = w
    return c
  }

  ** Before the window is full the average is over the time since the
  ** first execute plus 1E-10 seconds, so the first execute writes 0
  Void testStartup()
  {
    degF := Unit("°F")
    c := newComp(1min)
    c.set("in", sn(Number(7f, degF)))
    sim(c) |cx|
    {
      cx.step(at(0f)); verifyOut(c, 0f)
      verifyEq((c.get("out") as StatusNumber).num.unit, degF)
      cx.step(at(1f)); verifyOut(c, 7f / (1f + 1E-10f))
    }
  }

  ** The 1E-10 second guard leaves a constant in as it is from the first
  ** second, to 1E-8 relative
  Void testGuard()
  {
    c := newComp(1min)
    setIn(c, 100f)
    sim(c) |cx|
    {
      cx.step(at(0f)); verifyOut(c, 0f)
      (1..10).each |i| { cx.step(at(i.toFloat)); verifyOut(c, 100f, 1E-6f, Status.ok, "t=$i") }
    }
  }

  ** A step of in from 0 to 10 passes through a 5s window: out at 20 is
  ** 5/5 = 1, rising 2 a second to 10.
  Void testStepThroughWindow()
  {
    c := newComp(5sec)
    setIn(c, 0f)
    sim(c) |cx|
    {
      (0..19).each |i| { cx.step(at(i.toFloat)) }
      verifyOut(c, 0f)
      setIn(c, 10f)
      Float[][] rows := [[20f, 1f], [21f, 3f], [22f, 5f], [23f, 7f], [24f, 9f], [25f, 10f], [26f, 10f]]
      rows.each |r|
      {
        cx.step(at(r[0]))
        verifyOut(c, r[1], 1e-9f, Status.ok, "t=${r[0]}")
      }
    }
  }

  ** Null time is left out of the average: window 10s, in 5 to t=10,
  ** null to t=15, then 15, so out is 5 at 16, 7.5 at 17 and 15 at 20.
  Void testNullTimeLeftOut()
  {
    c := newComp(10sec)
    setIn(c, 5f)
    sim(c) |cx|
    {
      (0..10).each |i| { cx.step(at(i.toFloat)) }
      verifyOut(c, 5f)
      setIn(c, null)
      (11..15).each |i| { cx.step(at(i.toFloat)); verifyNull(c.get("out")) }
      setIn(c, 15f)
      cx.step(at(16f)); verifyOut(c, 5f, 1e-9f, Status.ok, "t=16")
      cx.step(at(17f)); verifyOut(c, 7.5f, 1e-9f, Status.ok, "t=17")
      cx.step(at(20f)); verifyOut(c, 15f, 1e-9f, Status.ok, "t=20")
      (21..25).each |i| { cx.step(at(i.toFloat)); verifyOut(c, 15f, 1e-9f, Status.ok, "t=$i") }
    }
  }

  ** A stall is left out, so a window with no valid time writes in, and a
  ** step past 1min but shorter than the window is a segment
  Void testStall()
  {
    c := newComp(10sec)
    sim(c) |cx|
    {
      setIn(c, 0f); cx.step(at(0f)); cx.step(at(1f))
      setIn(c, 6f); cx.step(at(3601f)); verifyOut(c, 6f)
      cx.step(at(3602f)); verifyOut(c, 6f)
    }

    d := newComp(2min)
    setIn(d, 0f)
    sim(d) |cx|
    {
      (0..13).each |i| { cx.step(at(10f * i.toFloat)) }
      setIn(d, 3f); cx.step(at(220f)); verifyOut(d, 135f / 120f)
    }
  }

  ** An invalid in holds out with its status, and a NaN or infinite in or
  ** a window below 10 microseconds faults
  Void testInvalidAndFaults()
  {
    c := newComp(5sec)
    setIn(c, 2f)
    sim(c) |cx|
    {
      (0..6).each |i| { cx.step(at(i.toFloat)) }
      setIn(c, 9f, stale); cx.step(at(7f)); verifyOut(c, 2f, 1e-9f, stale)
      setIn(c, Float.nan); cx.step(at(8f)); verifyOut(c, 2f, 1e-9f, fault)
      setIn(c, Float.posInf); cx.step(at(9f)); verifyOut(c, 2f, 1e-9f, fault)
      setIn(c, 2f, alarm); cx.step(at(10f)); verifyOut(c, 2f, 1e-9f, alarm)
      c.window = 5000ns; cx.step(at(11f)); verifyOut(c, 2f, 1e-9f, alarm.set(Status.fault))
    }
  }

  ** An overflow from finite inputs faults and keeps the history, and in 1
  ** then recovers and averages 1.
  Void testOverflow()
  {
    c := newComp(5sec)
    setIn(c, 1.7e308f)
    sim(c) |cx|
    {
      cx.step(at(0f)); verifyOut(c, 0f, 0f, Status.ok, "CDL's first value")
      (1..3).each |i| { cx.step(at(i.toFloat)); verifyOut(c, 0f, 0f, fault, "the overflow holds, t=$i") }
      setIn(c, 1f)
      cx.step(at(4f)); verifyOut(c, 0f, 0f, Status.ok, "in back: the segment from the overflow is left out")
      (5..40).each |i| { cx.step(at(i.toFloat)); verifyOut(c, 1f, 1e-9f, Status.ok, "t=$i") }
    }
  }
}
