//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

class AccumTimerTest : HxCompTest
{
  ** out totals the time in is true, passed holds, reset wins, a clock step back adds nothing
  Void testAccumTimer()
  {
    c := newTimer(10sec)
    sim(c) |cx, t0|
    {
      stepIR(cx, c, false, false, t0);       verifyT(c, 0f, false)
      stepIR(cx, c, true, false, t0+1sec);   verifyT(c, 0f, false)
      stepIR(cx, c, false, false, t0+7sec);  verifyT(c, 6f, false)
      stepIR(cx, c, true, false, t0+20sec);  verifyT(c, 6f, false)
      cx.step(t0+23.5sec);                   verifyT(c, 9.5f, false)
      cx.step(t0+24sec);                     verifyT(c, 10f, true)
      cx.step(t0+24.5sec);                   verifyT(c, 10f, true)
      stepIR(cx, c, false, false, t0+26sec); verifyT(c, 12f, true)
      stepIR(cx, c, true, true, t0+30sec);   verifyT(c, 0f, false)
      cx.step(t0+32sec);                     verifyT(c, 2f, false)
      stepIR(cx, c, false, true, t0+33sec);  verifyT(c, 3f, false)
      stepIR(cx, c, true, false, t0+34sec);  verifyT(c, 3f, false)
      cx.step(t0+34sec-1hr);                 verifyT(c, 3f, false)
      cx.step(t0+36sec-1hr);                 verifyT(c, 5f, false)
      verifyEq(c.out.num.unit, Unit("s"))
    }
  }

  ** A threshold of zero or less passes at the start, whatever in is, and again after a reset
  Void testZeroThreshold()
  {
    [0sec, -1sec].each |threshold|
    {
      c := newTimer(threshold)
      sim(c) |cx, t0|
      {
        stepIR(cx, c, false, false, t0);       verifyT(c, 0f, true)
        cx.step(t0+1sec);                      verifyT(c, 0f, true)
        stepIR(cx, c, false, true, t0+2sec);   verifyT(c, 0f, true)
      }
    }
  }

  ** A fall seen in the execute that takes out past the threshold leaves passed false
  Void testFallPastThreshold()
  {
    c := newTimer(10sec)
    sim(c) |cx, t0|
    {
      stepIR(cx, c, true, false, t0);          verifyT(c, 0f, false)
      cx.step(t0+9.5sec);                      verifyT(c, 9.5f, false)
      stepIR(cx, c, false, false, t0+10.5sec); verifyT(c, 10.5f, false)
    }
  }

  ** The same when in goes invalid or null while true, before the threshold, and then falls
  Void testFallAfterGap()
  {
    [sb(true, Status.down), null].each |gap|
    {
      c := newTimer(10sec)
      sim(c) |cx, t0|
      {
        stepIR(cx, c, true, false, t0);          verifyT(c, 0f, false)
        cx.step(t0+9.5sec);                      verifyT(c, 9.5f, false)
        stepIR(cx, c, gap, false, t0+9.8sec)
        if (gap == null) verifyT(c, null, null)
        else verifyT(c, 9.5f, false, Status.down)
        stepIR(cx, c, false, false, t0+10.5sec); verifyT(c, 10.5f, false)
      }
    }
  }

  ** A fall at the threshold leaves passed false, and the next rise passes it
  Void testFallAtThreshold()
  {
    c := newTimer(10sec)
    sim(c) |cx, t0|
    {
      stepIR(cx, c, true, false, t0);          verifyT(c, 0f, false)
      cx.step(t0+9.5sec);                      verifyT(c, 9.5f, false)
      stepIR(cx, c, false, false, t0+10sec);   verifyT(c, 10f, false)
      stepIR(cx, c, true, false, t0+20sec);    verifyT(c, 10f, true)
    }
  }

  ** A reset after a fall at the threshold sets out to 0, so the next rise
  ** leaves passed false until the total reaches the threshold again
  Void testResetAfterFallAtThreshold()
  {
    c := newTimer(10sec)
    sim(c) |cx, t0|
    {
      stepIR(cx, c, true, false, t0);          verifyT(c, 0f, false)
      cx.step(t0+9.5sec);                      verifyT(c, 9.5f, false)
      stepIR(cx, c, false, false, t0+10sec);   verifyT(c, 10f, false)
      stepIR(cx, c, false, true, t0+15sec);    verifyT(c, 0f, false)
      stepIR(cx, c, true, false, t0+20sec);    verifyT(c, 0f, false)
      cx.step(t0+29.5sec);                     verifyT(c, 9.5f, false)
      cx.step(t0+30sec);                       verifyT(c, 10f, true)
    }
  }

  ** A null or unlinked input nulls both outputs and an invalid one holds them
  Void testNullAndInvalid()
  {
    c := newTimer(10sec)
    sim(c) |cx, t0|
    {
      stepIR(cx, c, true, null, t0);         verifyT(c, null, null)
      stepIR(cx, c, true, false, t0+1sec);   verifyT(c, 0f, false)
      stepIR(cx, c, null, false, t0+3sec);   verifyT(c, null, null)
      stepIR(cx, c, false, false, t0+5sec);  verifyT(c, 4f, false)
      stepIR(cx, c, sb(true), sb(false, Status.fault), t0+6sec)
      verifyT(c, 4f, false, Status.fault)
      stepIR(cx, c, false, false, t0+9sec);  verifyT(c, 4f, false)
      stepIR(cx, c, sb(true, Status.alarm), sb(false), t0+10sec)
      verifyT(c, 4f, false, Status.alarm)
      stepIR(cx, c, null, false, t0+11sec)
      stepIR(cx, c, sb(true, Status.down), sb(false), t0+12sec)
      verifyT(c, null, null)
    }
  }

  private AccumTimer newTimer(Duration threshold)
  {
    AccumTimer c := createComp("AccumTimer")
    c.threshold = threshold
    return c
  }

  private Void sim(Comp c, |SimulatedCompContext, DateTime| f)
  {
    SimulatedCompContext(cs).asCur |cx| { cs.root.add(c); f(cx, cx.now); cs.root.remove(c.name) }
  }

  private Void stepIR(SimulatedCompContext cx, Comp c, Obj? in, Obj? reset, DateTime ts)
  {
    c.set("in", in is Bool ? sb(in) : in)
    c.set("reset", reset is Bool ? sb(reset) : reset)
    cx.step(ts)
  }

  private Void verifyT(AccumTimer c, Float? secs, Bool? passed, Status status := Status.ok)
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
