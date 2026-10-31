//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

class BoolHoldTest : HxCompTest
{
  ** A change passes at once unless a hold is running, then applies at its end
  Void testHold()
  {
    verifyEq(createComp("BoolHold")->falseHold, 0sec)
    c := newHold(10sec, 2sec)
    sim(c) |cx, t0|
    {
      verifyNull(c.out)
      stepIn(cx, c, true, t0);        verifyOut(c, true)
      stepIn(cx, c, false, t0+1sec);  verifyOut(c, true)
      cx.step(t0+9sec);               verifyOut(c, true)
      cx.step(t0+10sec);              verifyOut(c, false)
      stepIn(cx, c, true, t0+11sec);  verifyOut(c, false)
      cx.step(t0+12sec);              verifyOut(c, true)
      stepIn(cx, c, false, t0+13sec); verifyOut(c, true)
      stepIn(cx, c, true, t0+14sec);  verifyOut(c, true)
      cx.step(t0+22sec);              verifyOut(c, true)
      stepIn(cx, c, false, t0+30sec); verifyOut(c, false)
    }
  }

  ** A null in sets out to null and an invalid in holds it, both keep the hold
  Void testNullAndInvalid()
  {
    c := newHold(10sec, 10sec)
    sim(c) |cx, t0|
    {
      stepIn(cx, c, null, t0);        verifyOut(c, null)
      stepIn(cx, c, false, t0+1sec);  verifyOut(c, false)
      stepIn(cx, c, true, t0+20sec);  verifyOut(c, true)
      stepIn(cx, c, null, t0+22sec);  verifyOut(c, null)
      stepIn(cx, c, false, t0+23sec); verifyOut(c, true)
      stepIn(cx, c, sb(false, Status.fault), t0+30sec)
      verifyStatus(sb(true, Status.fault), c.out)
      stepIn(cx, c, false, t0+31sec)
      verifyStatus(sb(false), c.out)
      stepIn(cx, c, null, t0+32sec)
      stepIn(cx, c, sb(true, Status.down), t0+33sec); verifyOut(c, null)
    }
  }

  ** A clock step back counts as no time, so a hold does not lapse early
  Void testClockBackward()
  {
    c := newHold(10sec, 10sec)
    sim(c) |cx, t0|
    {
      stepIn(cx, c, false, t0)
      stepIn(cx, c, true, t0+20sec)
      stepIn(cx, c, false, t0+21sec)
      cx.step(t0-1hr);  verifyOut(c, true)
      cx.step(t0-1hr+8.999sec); verifyOut(c, true)
      cx.step(t0-1hr+9sec); verifyOut(c, false)
    }
  }

  private BoolHold newHold(Duration trueHold, Duration falseHold)
  {
    BoolHold c := createComp("BoolHold")
    c.trueHold  = trueHold
    c.falseHold = falseHold
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

  private Void verifyOut(BoolHold c, Bool? expected)
  {
    if (expected == null) verifyNull(c.out)
    else verifyEq(c.out?.val, expected)
  }
}
