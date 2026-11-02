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
** Derivative: the CDL Reals.Derivative block
**
class DerivativeTest : ContinuousCompTest
{
  Derivative newComp(Float k := 1f, Obj t := 1f, Float y0 := 0f)
  {
    c := (Derivative)createComp("Derivative")
    c.k = Number(k)
    c.timeConst = t is Number ? (Number)t : Number((Float)t)
    c.yStart = Number(y0)
    return c
  }

  ** A ramp of slope 1 with k = 2 settles toward 2
  Void testRampSettles()
  {
    c := newComp(2f)
    sim(c) |cx|
    {
      setIn(c, 0f); cx.step(at(0f)); verifyOut(c, 0f)
      setIn(c, 1f); cx.step(at(1f)); verifyOut(c, 1f)
      setIn(c, 2f); cx.step(at(2f)); verifyOut(c, 1.5f)
      setIn(c, 3f); cx.step(at(3f)); verifyOut(c, 1.75f)
    }
  }

  ** out starts at yStart, and a step of 3 times timeConst decays it by
  ** T/(T + dt) = 0.25 without changing sign
  Void testYStartLargeStep()
  {
    c := newComp(2f, 0.1f, 5f)
    setIn(c, 4f)
    sim(c) |cx|
    {
      cx.step(at(0f)); verifyOut(c, 5f)
      cx.step(at(0.3f)); verifyOut(c, 1.25f)
      cx.step(at(0.6f)); verifyOut(c, 0.3125f)
    }
  }

  ** With timeConst 0 out is the difference quotient, and 0 at first
  Void testZeroTimeConst()
  {
    c := newComp(1f, 0f, 5f)
    sim(c) |cx|
    {
      setIn(c, 0f); cx.step(at(0f)); verifyOut(c, 0f)
      setIn(c, 1f); cx.step(at(1f)); verifyOut(c, 1f)
      setIn(c, 4f); cx.step(at(1.5f)); verifyOut(c, 6f)
    }
  }

  ** A step longer than both 1min and timeConst is a gap: out holds and
  ** the next step starts from there
  Void testStallIsAGap()
  {
    c := newComp
    sim(c) |cx|
    {
      setIn(c, 0f); cx.step(at(0f)); cx.step(at(1f))
      setIn(c, 10f); cx.step(at(3601f)); verifyOut(c, 0f)
      setIn(c, 11f); cx.step(at(3602f)); verifyOut(c, 0.5f)
    }

    h := newComp(1f, 7200f)
    sim(h) |cx|
    {
      setIn(h, 0f); cx.step(at(0f)); cx.step(at(1f))
      setIn(h, 3600f); cx.step(at(3601f)); verifyOut(h, 1f / 3f)
    }
  }

  ** A null in writes null, an invalid in holds out with its status, a
  ** NaN or infinite in faults, and none of them is a step
  Void testNullInvalidNaN()
  {
    c := newComp
    sim(c) |cx|
    {
      setIn(c, 0f); cx.step(at(0f))
      setIn(c, 1f); cx.step(at(1f)); verifyOut(c, 0.5f)
      setIn(c, 50f, stale); cx.step(at(2f)); verifyOut(c, 0.5f, 1e-9f, stale)
      setIn(c, Float.nan); cx.step(at(3f)); verifyOut(c, 0.5f, 1e-9f, fault)
      setIn(c, Float.posInf); cx.step(at(4f)); verifyOut(c, 0.5f, 1e-9f, fault)
      setIn(c, null); cx.step(at(5f)); verifyNull(c.get("out"))
      setIn(c, 1f, alarm); cx.step(at(6f)); verifyOut(c, 0.5f, 1e-9f, alarm)
      cx.step(at(7f)); verifyOut(c, 0.25f, 1e-9f, alarm)
    }
  }

  ** A timeConst below 0 or not a time, or a k that is not finite, faults
  ** with the in status and holds yStart, an overflow faults and holds out,
  ** and an infinite yStart is NaN with fault
  Void testFaults()
  {
    c := newComp(1f, -1f, 3f)
    setIn(c, 1f, alarm)
    f := alarm.set(Status.fault)
    sim(c) |cx|
    {
      cx.step(at(0f)); verifyOut(c, 3f, 1e-9f, f)
      c.timeConst = Number(1f, Unit("°F"))
      cx.step(at(1f)); verifyOut(c, 3f, 1e-9f, f)
      c.timeConst = Number(1f); c.k = Number(Float.nan)
      cx.step(at(2f)); verifyOut(c, 3f, 1e-9f, f)
      c.k = Number(1f)
      cx.step(at(3f)); verifyOut(c, 3f, 1e-9f, alarm)
    }

    o := newComp(1e300f, 0f)
    sim(o) |cx|
    {
      setIn(o, 0f); cx.step(at(0f))
      setIn(o, 1e10f); cx.step(at(1f)); verifyOut(o, 0f, 0f, fault)
    }

    z := newComp(1f, 1f, Float.posInf)
    setIn(z, 1f)
    sim(z) |cx| { cx.step(at(0f)); verifyNaNFault(z) }
  }

  ** k and timeConst are slots: a timeConst of 500ms is 0.5s, and a
  ** StatusNumberToNumber linked into k schedules the gain
  Void testSlots()
  {
    c := newComp(1f, Number(500f, Unit("ms")))
    conv := createComp("StatusNumberToNumber")
    sim(c) |cx|
    {
      cs.root.add(conv)
      conv.set("in", sn(1))
      c.set("links", c.links.add("k", Etc.link(conv.id, "out")))
      setIn(c, 0f); cx.step(at(0f))
      setIn(c, 1f); cx.step(at(0.5f)); verifyOut(c, 1f)
      conv.set("in", sn(2))
      setIn(c, 2f); cx.step(at(1f)); verifyOut(c, 3f)
    }
  }
}
