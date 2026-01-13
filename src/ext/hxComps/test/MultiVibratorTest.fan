//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   07 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

class MultiVibratorTest : HxCompTest
{
  MultiVibrator newMv() { createComp("MultiVibrator") }

  Void test()
  {
    verifyMultiVibrator(newMv)
  }

  Void testPeriod()
  {
    mv := newMv
    mv.period = 60sec
    verifyMultiVibrator(mv)
  }

  Void testCycle()
  {
    mv := newMv
    mv.dutyCycle = 25
    verifyMultiVibrator(mv)
  }

  private Void verifyMultiVibrator(MultiVibrator mv)
  {
    period := mv.period
    cycle  := mv.dutyCycle

    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now
      verifyEq(ts, Date.today.midnight)

      // mount and prime
      cs.root.add(mv)
      cx.step(DateTime.defVal)
      cx.step(DateTime.defVal+1sec)
      cx.step(ts)

      start   := ts
      onTime  := period * (cycle/100f)
      offTime := period * ((100f-cycle)/100f)

      steps := 10
      stepTime := period * (1f/steps)
      steps.times |i|
      {
        cx.step(ts += stepTime)
        if (ts < start + onTime) verifyEq(mv.out, sb(true))
        else if (ts < start + period) verifyEq(mv.out, sb(false))
        else verifyEq(mv.out, sb(true))
      }
    }
  }
}