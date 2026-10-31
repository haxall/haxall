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
** Integrator: the CDL Reals.IntegratorWithReset block
**
class IntegratorTest : ContinuousCompTest
{
  Integrator newComp(Float k := 1f, Float y0 := 0f)
  {
    c := (Integrator)createComp("Integrator")
    c.k = Number(k)
    c.yStart = Number(y0)
    return c
  }

  ** Each step is the trapezoid from the last in to the current one, and a
  ** clock that steps back adds nothing
  Void testTrapezoid()
  {
    c := newComp(2f, 1f)
    sim(c) |cx|
    {
      setIn(c, 0f); cx.step(at(0f)); verifyOut(c, 1f)
      setIn(c, 2f); cx.step(at(1f)); verifyOut(c, 3f)
      cx.step(at(2f)); verifyOut(c, 7f)
      setIn(c, 4f); cx.step(at(2.5f)); verifyOut(c, 10f)
      setIn(c, -4f); cx.step(at(3.5f)); verifyOut(c, 10f)
      cx.step(at(3f)); verifyOut(c, 10f)
      cx.step(at(4f)); verifyOut(c, 2f)
    }
  }

  ** The reset is edge-triggered, never on the first execute, and a null
  ** inResetVal resets to yStart
  Void testResetEdge()
  {
    c := newComp
    setIn(c, 1f)
    setN(c, "inResetVal", 5f)
    c.set("inReset", sb(true))
    sim(c) |cx|
    {
      cx.step(at(0f)); verifyOut(c, 0f)
      cx.step(at(1f)); verifyOut(c, 1f)
      c.set("inReset", sb(false)); cx.step(at(2f)); verifyOut(c, 2f)
      c.set("inReset", sb(true)); cx.step(at(3f)); verifyOut(c, 5f)
      cx.step(at(4f)); verifyOut(c, 6f)
      c.set("inReset", sb(false)); cx.step(at(5f))
      c.set("inReset", sb(true)); c.set("inResetVal", null)
      cx.step(at(6f)); verifyOut(c, 0f)
    }
  }

  ** A reset waits through a stale inResetVal, then takes it plus what was
  ** integrated since the edge
  Void testResetWaits()
  {
    c := newComp
    setIn(c, 2f)
    c.set("inReset", sb(false))
    sim(c) |cx|
    {
      cx.step(at(0f))
      c.set("inReset", sb(true)); setN(c, "inResetVal", 7f, stale)
      cx.step(at(1f)); verifyOut(c, 2f, 1e-9f, stale)
      setN(c, "inResetVal", 7f)
      cx.step(at(2f)); verifyOut(c, 9f)
    }
  }

  ** A null in writes null, an invalid in holds out with its status, a
  ** NaN or infinite in faults, and none of that time is integrated
  Void testNullInvalidNaN()
  {
    c := newComp
    setIn(c, 2f)
    sim(c) |cx|
    {
      cx.step(at(0f)); cx.step(at(1f)); verifyOut(c, 2f)
      setIn(c, 5f, stale); cx.step(at(2f)); verifyOut(c, 2f, 1e-9f, stale)
      setIn(c, Float.nan); cx.step(at(3f)); verifyOut(c, 2f, 1e-9f, fault)
      setIn(c, Float.posInf); cx.step(at(4f)); verifyOut(c, 2f, 1e-9f, fault)
      setIn(c, null); cx.step(at(5f)); verifyNull(c.get("out"))
      setIn(c, 2f, alarm); cx.step(at(6f)); verifyOut(c, 2f, 1e-9f, alarm)
      cx.step(at(7f)); verifyOut(c, 4f, 1e-9f, alarm)
    }
  }

  ** A long gap counts as 1min: k = 0.5, in = 2, so an hour adds 60
  Void testStall()
  {
    c := newComp(0.5f, 0f)
    setIn(c, 2f)
    sim(c) |cx|
    {
      cx.step(at(0f)); cx.step(at(1f)); verifyOut(c, 1f)
      cx.step(at(3601f)); verifyOut(c, 61f, 1e-9f, Status.ok, "an hour counts as 1min")
      cx.step(at(3602f)); verifyOut(c, 62f, 1e-9f)
      cx.step(at(3662f)); verifyOut(c, 122f, 1e-9f, Status.ok, "exactly 1min is not capped")
    }
  }

  ** A stall is judged against 10 times the longest recent step: on 2min
  ** cycles only the first counts as 1min, and an hour counts as 20min
  Void testStallReference()
  {
    c := newComp
    setIn(c, 1f)
    sim(c) |cx|
    {
      cx.step(at(0f))
      cx.step(at(120f)); verifyOut(c, 60f)
      cx.step(at(240f)); verifyOut(c, 180f)
      cx.step(at(3840f)); verifyOut(c, 1380f)
    }
  }

  ** A k or yStart that is not finite, or an overflow, faults and holds,
  ** and an infinite yStart is NaN with fault
  Void testFaults()
  {
    c := newComp(Float.nan, 2f)
    setIn(c, 1f, alarm)
    f := alarm.set(Status.fault)
    sim(c) |cx|
    {
      cx.step(at(0f)); verifyOut(c, 2f, 1e-9f, f)
      c.k = Number(1f)
      cx.step(at(1f)); verifyOut(c, 2f, 1e-9f, alarm)
      cx.step(at(2f)); verifyOut(c, 3f, 1e-9f, alarm)
      c.yStart = Number(Float.posInf)
      cx.step(at(3f)); verifyOut(c, 3f, 1e-9f, f)
    }

    o := newComp(1e200f)
    setIn(o, 1e200f)
    sim(o) |cx|
    {
      cx.step(at(0f)); cx.step(at(1f)); verifyOut(o, 0f, 0f, fault)
      setIn(o, 0f); cx.step(at(2f)); cx.step(at(3f)); verifyOut(o, 0f)
    }

    z := newComp(1f, Float.posInf)
    setIn(z, 1f)
    sim(z) |cx| { cx.step(at(0f)); verifyNaNFault(z) }
  }
}
