//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

class TimerTest : HxCompTest
{
  ** out counts the seconds in is true, refreshed once a second, until passed
  Void testTimer()
  {
    c := newTimer(10sec)
    sim(c) |cx, t0|
    {
      stepIn(cx, c, false, t0);       verifyT(c, 0f, false)
      stepIn(cx, c, true, t0+1sec);   verifyT(c, 0f, false)
      cx.step(t0+5sec);               verifyT(c, 4f, false)
      cx.step(t0+10.5sec);            verifyT(c, 9.5f, false)
      cx.step(t0+11sec);              verifyT(c, 10f, true)
      verifyEq(c.out.num.unit, Unit("s"))
      cx.step(t0+11.5sec);            verifyT(c, 10f, true)
      cx.step(t0+12sec);              verifyT(c, 11f, true)
      stepIn(cx, c, false, t0+13sec); verifyT(c, 0f, false)
      stepIn(cx, c, true, t0+20sec);  verifyT(c, 0f, false)
      cx.step(t0+22sec);              verifyT(c, 2f, false)
    }
  }

  ** A threshold of zero passes as soon as in is true
  Void testZeroThreshold()
  {
    c := newTimer(0sec)
    sim(c) |cx, t0|
    {
      stepIn(cx, c, false, t0);       verifyT(c, 0f, false)
      stepIn(cx, c, true, t0+1sec);   verifyT(c, 0f, true)
      stepIn(cx, c, false, t0+2sec);  verifyT(c, 0f, false)
      stepIn(cx, c, true, t0+3sec);   verifyT(c, 0f, true)
    }
  }

  ** With a threshold of zero, passed stays false while in is false from the start
  Void testPassedNeedsIn()
  {
    c := newTimer(0sec)
    sim(c) |cx, t0|
    {
      stepIn(cx, c, false, t0);       verifyT(c, 0f, false)
      cx.step(t0+1sec);               verifyT(c, 0f, false)
      cx.step(t0+2sec);               verifyT(c, 0f, false)
    }
  }

  ** With a threshold of zero or less, a true in at the first execute passes at once
  Void testPassedAtStart()
  {
    c := newTimer(0sec)
    sim(c) |cx, t0|
    {
      stepIn(cx, c, true, t0);        verifyT(c, 0f, true)
      cx.step(t0+1sec);               verifyT(c, 1f, true)
    }

    c = newTimer(-1sec)
    sim(c) |cx, t0|
    {
      stepIn(cx, c, true, t0);        verifyT(c, 0f, true)
      cx.step(t0+1sec);               verifyT(c, 1f, true)
    }
  }

  ** A negative threshold acts as zero
  Void testNegativeThreshold()
  {
    c := newTimer(-5sec)
    sim(c) |cx, t0|
    {
      stepIn(cx, c, false, t0);       verifyT(c, 0f, false)
      cx.step(t0+1sec);               verifyT(c, 0f, false)
      stepIn(cx, c, true, t0+2sec);   verifyT(c, 0f, true)
      stepIn(cx, c, false, t0+3sec);  verifyT(c, 0f, false)
    }
  }

  ** A null in nulls both outputs and an invalid in holds them, both keep the state
  Void testNullAndInvalid()
  {
    c := newTimer(10sec)
    sim(c) |cx, t0|
    {
      stepIn(cx, c, null, t0);        verifyT(c, null, null)
      stepIn(cx, c, true, t0+1sec);   verifyT(c, 0f, false)
      stepIn(cx, c, null, t0+2sec);   verifyT(c, null, null)
      stepIn(cx, c, true, t0+6sec);   verifyT(c, 5f, false)
      stepIn(cx, c, sb(true, Status.fault), t0+7sec); verifyT(c, 5f, false, Status.fault)
      stepIn(cx, c, true, t0+12sec);  verifyT(c, 11f, true)
      stepIn(cx, c, sb(true, Status.alarm), t0+13sec); verifyT(c, 12f, true, Status.alarm)
      stepIn(cx, c, null, t0+14sec)
      stepIn(cx, c, sb(false, Status.down), t0+15sec); verifyT(c, null, null)
    }
  }

  ** A clock step back counts as no time, so passed does not come early
  Void testClockBackward()
  {
    c := newTimer(10sec)
    sim(c) |cx, t0|
    {
      stepIn(cx, c, false, t0)
      stepIn(cx, c, true, t0+1sec)
      c.execute
      cx.step(t0-1hr);       verifyT(c, 0f, false)
      cx.step(t0-1hr+4sec);  verifyT(c, 4f, false)
      cx.step(t0-1hr+10sec); verifyT(c, 10f, true)
    }
  }

  private Timer newTimer(Duration threshold)
  {
    Timer c := createComp("Timer")
    c.threshold = threshold
    return c
  }

  private Void sim(Comp c, |SimulatedCompContext, DateTime| f)
  {
    SimulatedCompContext(cs).asCur |cx| { cs.root.add(c); f(cx, cx.now); cs.root.remove(c.name) }
  }

  private Void stepIn(SimulatedCompContext cx, Comp c, Obj? val, DateTime ts)
  {
    c.set("in", val is Bool ? sb(val) : val)
    cx.step(ts)
  }

  private Void verifyT(Timer c, Float? secs, Bool? passed, Status status := Status.ok)
  {
    if (secs == null) verifyNull(c.out)
    else
    {
      verifyNotNull(c.out)
      verify(c.out.num.toFloat.approx(secs), "out ${c.out.num} != ${secs}")
      verifyEq(c.out.status, status)
    }
    if (passed == null) verifyNull(c.passed)
    else verifyStatus(sb(passed, status), c.passed)
  }
}
