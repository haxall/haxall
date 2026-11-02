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
** SlewRateLimit: the CDL Reals.LimitSlewRate and Reals.Ramp blocks
**
class SlewRateLimitTest : ContinuousCompTest
{
  SlewRateLimit newComp(Float r, Float? f := null, Duration? td := null)
  {
    c := (SlewRateLimit)createComp("SlewRateLimit")
    c.raisingSlewRate = Number(r)
    c.fallingSlewRate = f == null ? null : Number(f)
    c.timeConst = td
    return c
  }

  ** Within the rates out takes a backward Euler step toward the current
  ** in at (in - out)/timeConst, and a clock that steps back adds nothing
  Void testApproach()
  {
    c := newComp(10f, null, 1sec)
    setIn(c, 0f)
    sim(c) |cx|
    {
      cx.step(at(0f)); verifyOut(c, 0f)
      setIn(c, 2f); cx.step(at(1f)); verifyOut(c, 1f)
      cx.step(at(2f)); verifyOut(c, 1.5f)
      cx.step(at(1f)); verifyOut(c, 1.5f)
      cx.step(at(2f)); verifyOut(c, 1.75f)
    }
  }

  ** The rates limit out, and a null fallingSlewRate is minus
  ** raisingSlewRate
  Void testRates()
  {
    [null, -2f].each |Float? f|
    {
      c := newComp(0.5f, f, 10ms)
      setIn(c, 0f)
      sim(c) |cx|
      {
        cx.step(at(0f))
        setIn(c, 10f); cx.step(at(2f)); verifyOut(c, 1f)
        setIn(c, -10f); cx.step(at(3f)); verifyOut(c, f == null ? 0.5f : -1f)
      }
    }
  }

  ** enable through a StatusBoolToBool link, as CDL Ramp's active: out is
  ** in while disabled, and a re-enable starts from in.
  Void testEnable()
  {
    c := newComp(1f, null, 10ms)
    conv := createComp("StatusBoolToBool")
    sim(c) |cx|
    {
      cs.root.add(conv)
      c.set("links", c.links.add("enable", Etc.link(conv.id, "out")))
      conv.set("in", sb(true))
      setIn(c, 0f); cx.step(at(0f)); verifyOut(c, 0f)
      setIn(c, 10f); cx.step(at(1f)); verifyOut(c, 1f, 1e-9f, Status.ok, "limited")
      conv.set("in", sb(false))
      setIn(c, 7f); cx.step(at(2f)); verifyOut(c, 7f, 1e-9f, Status.ok, "disabled: out is in")
      verifyEq(c.enable, false)
      setIn(c, -3f); cx.step(at(3f)); verifyOut(c, -3f)
      conv.set("in", sb(true))
      setIn(c, 4f); cx.step(at(4f)); verifyOut(c, 4f, 1e-9f, Status.ok, "enabled: starts from in")
      setIn(c, 10f); cx.step(at(5f)); verifyOut(c, 5f, 1e-9f, Status.ok, "then limited")
    }
  }

  ** A null in writes null, an invalid in holds out with its status, a
  ** NaN or infinite in faults, and out has the unit of in
  Void testNullInvalidNaN()
  {
    c := newComp(1f, null, 10ms)
    degF := Unit("°F")
    sim(c) |cx|
    {
      c.set("in", sn(Number(5f, degF))); cx.step(at(0f)); verifyOut(c, 5f)
      verifyEq((c.get("out") as StatusNumber).num.unit, degF)
      c.set("in", sn(Number(50f, degF), stale)); cx.step(at(1f)); verifyOut(c, 5f, 1e-9f, stale)
      c.set("in", sn(Number(Float.nan, degF))); cx.step(at(2f)); verifyOut(c, 5f, 1e-9f, fault)
      c.set("in", sn(Number(Float.posInf, degF))); cx.step(at(3f)); verifyOut(c, 5f, 1e-9f, fault)
      c.set("in", null); cx.step(at(4f)); verifyNull(c.get("out"))
      c.set("in", sn(Number(9f, degF), alarm)); cx.step(at(5f)); verifyOut(c, 5f, 1e-9f, alarm)
      cx.step(at(6f)); verifyOut(c, 6f, 1e-9f, alarm)
    }
  }

  ** A stall counts as its threshold: after 1s cycles an hour moves out
  ** 1min at the rate, and a 2min step after it moves 2min
  Void testStallBounded()
  {
    c := newComp(0.01f, null, 1sec)
    setIn(c, 0f)
    sim(c) |cx|
    {
      cx.step(at(0f)); cx.step(at(1f))
      setIn(c, 10f); cx.step(at(3601f)); verifyOut(c, 0.6f)
      cx.step(at(3721f)); verifyOut(c, 1.8f)
    }
  }

  ** A rate of the wrong sign or unit, or a timeConst of 0, faults with the
  ** in status, and a rate with a time unit is per that unit
  Void testRateConfig()
  {
    c := newComp(0f, -1f, 1sec)
    f := alarm.set(Status.fault)
    setIn(c, 3f, alarm)
    sim(c) |cx|
    {
      cx.step(at(0f)); verifyOut(c, 3f, 1e-9f, f)
      c.raisingSlewRate = Number(1f); c.fallingSlewRate = Number(1f)
      cx.step(at(1f)); verifyOut(c, 3f, 1e-9f, f)
      c.fallingSlewRate = Number(-1f, Unit("°F/min"))
      cx.step(at(2f)); verifyOut(c, 3f, 1e-9f, f)
      c.fallingSlewRate = null; c.timeConst = 0sec
      cx.step(at(3f)); verifyOut(c, 3f, 1e-9f, f)
      c.raisingSlewRate = Number(6f, Unit("/min")); c.timeConst = 10ms
      cx.step(at(4f)); verifyOut(c, 3f, 1e-9f, alarm)
      setIn(c, 10f, alarm); cx.step(at(14f)); verifyOut(c, 4f, 1e-9f, alarm)
    }
  }

  ** An overflow from finite inputs faults and keeps the state while it
  ** lasts, then in 1 steps from the kept state: 0.5, then 0.75.
  Void testOverflow()
  {
    c := newComp(1e308f, -1e308f, 1sec)
    sim(c) |cx|
    {
      setIn(c, 0f); cx.step(at(0f)); verifyOut(c, 0f)
      setIn(c, 1e308f); cx.step(at(60f)); verifyOut(c, 0f, 0f, fault, "overflow: kept, last value with fault")
      cx.step(at(120f)); verifyOut(c, 0f, 0f, fault, "the overflow holds")
      setIn(c, 1f); cx.step(at(121f)); verifyOut(c, 0.5f, 1e-12f, Status.ok, "a step from the kept state")
      cx.step(at(122f)); verifyOut(c, 0.75f, 1e-12f, Status.ok, "slews on")
    }
  }
}
