//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jun 2025  Matthew Giannini  Creation
//

using haystack

class CurTimeTest : HxCompTest
{
  private CurTime createTime() { createComp("CurTime") }

  Void testDefaults()
  {
    verifyCurTime(createTime)
  }

  Void testUpdateFreq()
  {
    time := createTime
    time.updateFreq = 1sec
    verifyCurTime(time)
    verifyEq(1sec, time.updateFreq)
  }

  Void testBadUpdateFreq()
  {
    SimulatedCompContext(cs).asCur |cx|
    {
      ts   := cx.now
      time := createTime
      cs.root.add(time)

      // setting to invalid freq should result in no change to the freq
      freq := time.updateFreq
      time.updateFreq = 0sec
      verifyEq(freq, time.updateFreq)

      time.updateFreq = 1min
      verifyEq(1min, time.updateFreq)
      // this should reset the update freq back to original default
      time.updateFreq = 0sec
      verifyEq(freq, time.updateFreq)
    }
  }


  private Void verifyCurTime(CurTime time)
  {
    SimulatedCompContext(cs).asCur |cx|
    {
      ts   := cx.now
      freq := time.updateFreq

      // mount the comp
      cs.root.add(time)

      // prime the comp
      cx.step(ts)

      prevTime := time.out
      10.times |i|
      {
        cx.step(ts += freq/2)

        if (i % 2 == 0) verifyEq(prevTime, time.out)
        else verifyEq(ts, time.out)

        prevTime = time.out
      }
    }
  }

}