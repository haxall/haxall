//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

class CounterTest : HxCompTest
{
  ** Counts rises of trigger from initVal, and reset goes back to initVal
  Void testCounter()
  {
    TestHxCompContext().asCur |cx|
    {
      c := newCounter(10)
      verifyNull(c.out)
      step(c, true,  false, 10)
      step(c, false, false, 10)
      step(c, true,  false, 11)
      step(c, true,  false, 11)
      step(c, false, false, 11)
      step(c, true,  false, 12)
      verifyNull(c.out.num.unit)
      step(c, false, true,  10)
      step(c, true,  true,  10)
      step(c, false, false, 10)
      step(c, true,  false, 11)
      step(c, false, false, 11)
      step(c, true,  true,  10)
    }
  }

  ** A null input nulls out and an invalid one holds it, both keep the count
  Void testNullAndInvalid()
  {
    TestHxCompContext().asCur |cx|
    {
      c := newCounter
      set(c, true, null); verifyNull(c.out)
      step(c, false, false, 0)
      step(c, true,  false, 1)
      set(c, null, false); verifyNull(c.out)
      step(c, false, false, 1)
      set(c, sb(true, Status.fault), sb(false))
      verifyStatus(sn(1, Status.fault), c.out)
      step(c, true, false, 2)
      set(c, sb(false, Status.alarm), sb(false))
      verifyStatus(sn(2, Status.alarm), c.out)
      set(c, null, false)
      set(c, sb(true, Status.down), sb(false))
      verifyNull(c.out)
    }
  }

  private Counter newCounter(Int initVal := 0)
  {
    Counter c := createComp("Counter")
    c.initVal = initVal
    cs.root.add(c)
    return c
  }

  private Void step(Counter c, Bool trigger, Bool reset, Int expected)
  {
    set(c, trigger, reset)
    verifyStatus(sn(expected), c.out)
  }

  private Void set(Counter c, Obj? trigger, Obj? reset)
  {
    c.set("trigger", trigger is Bool ? sb(trigger) : trigger)
    c.set("reset", reset is Bool ? sb(reset) : reset)
    cs.execute
  }
}
