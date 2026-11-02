//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

class HysteresisTest : HxCompTest
{
  ** out turns true above B and false at or below B - deadband
  Void testGreaterThanHys()
  {
    TestHxCompContext().asCur |cx|
    {
      c := mk("GreaterThanHys", ["inB":sn(5), "deadband":n(1)])
      stepA(c, 5, false)
      stepA(c, 6, true)
      stepA(c, 4.5f, true)
      stepA(c, 4, false)
      stepA(c, 4.5f, false)
      stepB(c, 4, true)
      setAndExec(c, "deadband", n(0))
      stepA(c, 4, false)
      verifyOut(mk("GreaterThanHys", ["inA":sn(4.5f), "inB":sn(5), "deadband":n(1), "initOut":true]), true)
    }
  }

  ** out turns true below B and false at or above B + deadband
  Void testLessThanHys()
  {
    TestHxCompContext().asCur |cx|
    {
      c := mk("LessThanHys", ["inB":sn(5), "deadband":n(1)])
      stepA(c, 5, false)
      stepA(c, 4, true)
      stepA(c, 5.5f, true)
      stepA(c, 6, false)
      stepA(c, 5.5f, false)
      stepB(c, 6, true)
      verifyOut(mk("LessThanHys", ["inA":sn(5.5f), "inB":sn(5), "deadband":n(1), "initOut":true]), true)
    }
  }

  ** out turns true above high and false below low
  Void testHysteresis()
  {
    TestHxCompContext().asCur |cx|
    {
      c := mk("Hysteresis", ["low":n(1), "high":n(3)])
      stepIn(c, 3, false)
      stepIn(c, 4, true)
      stepIn(c, 1, true)
      stepIn(c, 0.5f, false)
      stepIn(c, 2, false)
      verifyOut(mk("Hysteresis", ["in":sn(2), "low":n(1), "high":n(3), "initOut":true]), true)
    }
  }

  ** A null input clears out and an invalid one holds it, both keeping the state
  Void testNullAndInvalid()
  {
    TestHxCompContext().asCur |cx|
    {
      c := mk("GreaterThanHys", ["inB":sn(5), "deadband":n(1)])
      stepA(c, sn(6, Status.fault), null)
      stepA(c, 6, true)
      stepA(c, null, null)
      stepA(c, 4.5f, true)
      stepA(c, sn(0, Status.fault), true, Status.fault)
      stepA(c, 4.5f, true)
      stepA(c, sn(0, Status.alarm), false, Status.alarm)
      stepA(c, null, null)
      stepA(c, sn(9, Status.stale), null)

      h := mk("Hysteresis", ["in":sn(4), "low":n(1), "high":n(3)])
      stepIn(h, null, null)
      stepIn(h, 2, true)
      stepIn(h, sn(0, Status.stale), true, Status.stale)
    }
  }

  ** A bad deadband or limits, or a NaN input, faults on the held value
  Void testFaults()
  {
    TestHxCompContext().asCur |cx|
    {
      c := mk("GreaterThanHys", ["inA":sn(6), "inB":sn(5), "deadband":n(1)])
      setAndExec(c, "deadband", n(-1))
      verifyOut(c, true, Status.fault)
      stepA(c, 0, true, Status.fault)
      setAndExec(c, "deadband", n(Float.nan))
      verifyOut(c, true, Status.fault)
      setAndExec(c, "deadband", n(1))
      verifyOut(c, false)
      stepA(c, Float.nan, false, Status.fault)

      verifyOut(mk("Hysteresis", ["in":sn(5), "low":n(3), "high":n(3)]), false, Status.fault)
      verifyOut(mk("Hysteresis", ["in":sn(5), "low":n(1), "high":n(Float.nan), "initOut":true]), true, Status.fault)
      verifyOut(mk("LessThanHys", ["inA":sn(6, Status.down), "inB":sn(5), "deadband":n(-1)]), false, Status.down.set(Status.fault))
    }
  }

  ** The deadband is in the unit of inB or its delta unit
  Void testUnits()
  {
    TestHxCompContext().asCur |cx|
    {
      f := "fahrenheit"
      c := mk("GreaterThanHys", ["inB":sn(n(55, f)), "deadband":n(2, "fahrenheit_degrees")])
      stepA(c, n(56, f), true)
      stepA(c, n(54, f), true)
      stepA(c, n(53, f), false)
      setAndExec(c, "deadband", n(2, "celsius"))
      verifyOut(c, false, Status.fault)

      h := mk("Hysteresis", ["in":sn(n(66, f)), "low":n(60, f), "high":n(65)])
      verifyOut(h, true)
      setAndExec(h, "low", n(15, "celsius"))
      verifyOut(h, true, Status.fault)

      // incompatible inA and inB units: out holds in fault, no throw (as Comparison since 4.0.7)
      setAndExec(c, "deadband", n(2))
      c.set("inA", sn(n(10, "celsius")))
      c.onExecute
      verifyOut(c, false, Status.fault)
    }
  }

  private Comp mk(Str spec, Str:Obj? params)
  {
    c := createComp(spec)
    params.each |v, k| { c.set(k, v) }
    cs.root.add(c)
    cs.execute
    return c
  }

  private Void stepA(Comp c, Obj? v, Bool? exp, Status s := Status.ok) { step(c, "inA", v, exp, s) }
  private Void stepB(Comp c, Obj? v, Bool? exp, Status s := Status.ok) { step(c, "inB", v, exp, s) }
  private Void stepIn(Comp c, Obj? v, Bool? exp, Status s := Status.ok) { step(c, "in", v, exp, s) }

  ** Set a slot to a Num, a Number, a StatusNumber or null, then verify out
  private Void step(Comp c, Str slot, Obj? v, Bool? exp, Status s)
  {
    setAndExec(c, slot, v == null || v is StatusNumber ? v : sn(v))
    verifyOut(c, exp, s)
  }

  private Void verifyOut(Comp c, Bool? exp, Status s := Status.ok)
  {
    if (exp == null) verifyNull(c.get("out"))
    else verifyEq(c.get("out"), sb(exp, s))
  }
}
