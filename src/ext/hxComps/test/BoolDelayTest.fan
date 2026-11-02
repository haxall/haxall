//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

class BoolDelayTest : HxCompTest
{
  ** A rise sets out after onDelay and a fall clears it at once
  Void testOnDelay()
  {
    sim(10sec, 0sec) |cx, c, t0|
    {
      verifyIn(cx, c, false, t0, false)
      verifyIn(cx, c, true, t0+1sec, false)
      verifyAt(cx, c, t0+10sec, false)
      verifyAt(cx, c, t0+11sec, true)
      verifyIn(cx, c, false, t0+12sec, false)
    }
  }

  ** A fall before onDelay cancels the on-timer, so a rise after it waits a full onDelay
  Void testFallCancelsOnDelay()
  {
    sim(10sec, 0sec) |cx, c, t0|
    {
      verifyIn(cx, c, false, t0, false)
      verifyIn(cx, c, true, t0+1sec, false)
      verifyIn(cx, c, false, t0+5sec, false)
      verifyIn(cx, c, true, t0+8sec, false)
      verifyAt(cx, c, t0+11sec, false)
      verifyAt(cx, c, t0+17sec, false)
      verifyAt(cx, c, t0+18sec, true)
    }
  }

  ** A fall clears out after offDelay, and a rise before then cancels it
  Void testOffDelay()
  {
    sim(5sec, 10sec) |cx, c, t0|
    {
      verifyIn(cx, c, false, t0, false)
      verifyIn(cx, c, true, t0+1sec, false)
      verifyAt(cx, c, t0+6sec, true)
      verifyIn(cx, c, false, t0+7sec, true)
      verifyAt(cx, c, t0+16sec, true)
      verifyAt(cx, c, t0+17sec, false)
      verifyIn(cx, c, true, t0+20sec, false)
      verifyAt(cx, c, t0+25sec, true)
      verifyIn(cx, c, false, t0+26sec, true)
      verifyIn(cx, c, true, t0+30sec, true)
    }
  }

  Void testDelayOnInit()
  {
    sim(10sec, 0sec) |cx, c, t0|
    {
      verifyEq(c.delayOnInit, false)
      verifyIn(cx, c, true, t0, true)
    }

    sim(10sec, 0sec) |cx, c, t0|
    {
      c.delayOnInit = true
      verifyIn(cx, c, true, t0, false)
      verifyAt(cx, c, t0+9sec, false)
      verifyAt(cx, c, t0+10sec, true)
    }
  }

  ** A null in clears out and an invalid in holds it, both keeping a pending timer
  Void testNullAndInvalid()
  {
    sim(10sec, 0sec) |cx, c, t0|
    {
      verifyIn(cx, c, sb(true, Status.fault), t0, null)
      verifyIn(cx, c, false, t0+1sec, false)
      verifyIn(cx, c, true, t0+2sec, false)
      verifyIn(cx, c, null, t0+3sec, null)
      verifyIn(cx, c, sb(true, Status.stale), t0+4sec, null)
      verifyIn(cx, c, true, t0+5sec, false)
      verifyIn(cx, c, sb(false, Status.fault), t0+6sec, false)
      verifyIn(cx, c, sb(true, Status.overridden), t0+12sec, true)
      verifyEq(c.out.status, Status.overridden)
      verifyIn(cx, c, sb(false, Status.fault), t0+13sec, true)
      verifyEq(c.out.status, Status.fault)
      verifyEq(c.outNot.status, Status.fault)
    }
  }

  ** A delay change applies to a pending timer and counts the time served
  Void testDelayChange()
  {
    sim(10sec, 0sec) |cx, c, t0|
    {
      verifyIn(cx, c, false, t0, false)
      verifyIn(cx, c, true, t0+1sec, false)
      verifyAt(cx, c, t0+3sec, false)
      c.onDelay = 4sec
      verifyAt(cx, c, t0+4sec, false)
      verifyAt(cx, c, t0+5sec, true)
    }
  }

  ** A step of the clock backward counts as no time
  Void testClockStepBack()
  {
    sim(10sec, 0sec) |cx, c, t0|
    {
      verifyIn(cx, c, false, t0, false)
      verifyIn(cx, c, true, t0+1sec, false)
      verifyIn(cx, c, true, t0+5sec, false)
      verifyIn(cx, c, true, t0-1hr, false)
      verifyAt(cx, c, t0-1hr+5sec, false)
      verifyAt(cx, c, t0-1hr+6sec, true)
    }
  }

  ** Mount a BoolDelay in a fresh simulated context
  private Void sim(Duration onDelay, Duration offDelay, |SimulatedCompContext, BoolDelay, DateTime| f)
  {
    BoolDelay c := createComp("BoolDelay")
    c.onDelay  = onDelay
    c.offDelay = offDelay
    SimulatedCompContext(cs).asCur |cx|
    {
      cs.root.add(c)
      f(cx, c, cx.now)
      cs.root.remove(c.name)
    }
  }

  ** Set in to a Bool, a StatusBool or null, then step to ts and verify
  private Void verifyIn(SimulatedCompContext cx, BoolDelay c, Obj? in, DateTime ts, Bool? out)
  {
    c.set("in", in is Bool ? sb(in) : in)
    verifyAt(cx, c, ts, out)
  }

  ** Step to ts and verify out, and that outNot is its inverse
  private Void verifyAt(SimulatedCompContext cx, BoolDelay c, DateTime ts, Bool? out)
  {
    cx.step(ts)
    verifyEq(c.out?.val, out)
    verifyEq(c.outNot?.val, out == null ? null : !out)
  }
}
