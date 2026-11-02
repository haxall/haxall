//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Oct 2026  Lincoln Harmer  Creation
//

class OwnClockTest : Test
{
  ** The first tick starts the own clock at the host clock
  Void testFirstTick()
  {
    c := OwnClock()
    verifyEq(c.started, false)
    verifyEq(c.behind, false)
    verifyEq(c.tick(at(10sec)), at(10sec).ticks)
    verifyEq(c.ticks, at(10sec).ticks)
    verifyEq(c.step, 0)
    verifyEq(c.started, true)
    verifyEq(c.behind, false)
  }

  ** Forward steps add up, so the own clock equals the host clock
  Void testForwardSteps()
  {
    c := OwnClock()
    c.tick(at(0sec))
    [1sec, 1.5sec, 4sec, 4sec, 1hr].each |d|
    {
      verifyEq(c.tick(at(d)), at(d).ticks)
      verifyEq(c.behind, false)
    }
    verifyEq(c.step, 1hr.ticks - 4sec.ticks)
    c.tick(at(1hr))
    verifyEq(c.step, 0)
    verifyEq(c.behind, false)
  }

  ** A step back counts as no time and the time after it counts
  Void testStepBack()
  {
    c := OwnClock()
    c.tick(at(0sec))
    c.tick(at(10sec))
    verifyEq(c.tick(at(7sec)), at(10sec).ticks)
    verifyEq(c.step, 0)
    verifyEq(c.behind, true)
    verifyEq(c.tick(at(8sec)), at(11sec).ticks)
    verifyEq(c.step, 1sec.ticks)
    verifyEq(c.behind, true)
  }

  ** Two steps back: the time between counts and behind holds
  Void testTwoStepsBack()
  {
    c := OwnClock()
    c.tick(at(0sec))
    c.tick(at(10sec))
    c.tick(at(6sec))
    c.tick(at(7sec))
    verifyEq(c.tick(at(5sec)), at(11sec).ticks)
    verifyEq(c.behind, true)
    verifyEq(c.tick(at(9sec)), at(15sec).ticks)
    verifyEq(c.behind, true)
    verifyEq(c.tick(at(11sec)), at(17sec).ticks)
    verifyEq(c.behind, false)
  }

  ** A return to exactly the latest time seen clears behind
  Void testReturnToLatest()
  {
    c := OwnClock()
    c.tick(at(0sec))
    c.tick(at(10sec))
    c.tick(at(8sec))
    verifyEq(c.behind, true)
    verifyEq(c.tick(at(10sec)), at(12sec).ticks)
    verifyEq(c.behind, false)
  }

  ** After a jump forward and back, behind lasts until the far time
  Void testJumpForwardAndBack()
  {
    c := OwnClock()
    c.tick(at(0sec))
    c.tick(at(1day))
    verifyEq(c.ticks, at(1day).ticks)
    verifyEq(c.tick(at(1sec)), at(1day).ticks)
    verifyEq(c.behind, true)
    verifyEq(c.tick(at(1hr)), at(1day + 1hr - 1sec).ticks)
    verifyEq(c.behind, true)
    c.tick(at(1day - 1sec))
    verifyEq(c.behind, true)
    c.tick(at(1day))
    verifyEq(c.behind, false)
    verifyEq(c.ticks, at(2day - 1sec).ticks)
  }

  ** Host time d after a fixed UTC start
  private DateTime at(Duration d) { start + d }

  private static const DateTime start := DateTime("2026-01-01T00:00:00Z UTC")
}
