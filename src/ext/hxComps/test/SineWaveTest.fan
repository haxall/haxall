//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jun 2025  Matthew Giannini  Creation
//

using haystack

class SineWaveTest : HxCompTest
{
  SineWave newSineWave() { createComp("SineWave") }

  Void testDefaults()
  {
    verifySineWave(newSineWave)
  }

  Void testAmplitude()
  {
    SineWave sw := newSineWave
    sw.amplitude = 100f
    verifySineWave(sw)
    sw = newSineWave
    sw.amplitude = -100f
    verifySineWave(sw)
  }

  Void testPeriod()
  {
    SineWave sw := newSineWave
    sw.period = 60sec
    verifySineWave(sw)

    // period is clamped to at least 1sec
    sw = newSineWave
    sw.period = 0sec
    verifyEq(sw.period, 1sec)
    sw.period = -5sec
    verifyEq(sw.period, 1sec)
    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now
      cs.root.add(sw)
      cx.step(ts)

      // a 1sec period wraps back to the start every step
      cx.step(ts+1sec)
      verifyStatus(sw.out, sn(50))
      cx.step(ts+2sec)
      verifyStatus(sw.out, sn(50))
    }
  }

  Void testOffset()
  {
    SineWave sw := newSineWave
    sw.offset = 10f
    verifySineWave(sw)
    sw = newSineWave
    sw.offset= -10f
    verifySineWave(sw)
  }

  private Void verifySineWave(SineWave sw)
  {
    period    := sw.period
    amplitude := sw.amplitude
    offset    := sw.offset

    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now
      verifyEq(ts, Date.today.midnight)

      // mount the comp
      cs.root.add(sw)

      // prime the comp
      cx.step(ts)

      steps := 8
      frac  := 1f/steps
      steps.times |i|
      {
        percent := ((i+1)%steps)*frac

        cx.step(ts += (period*frac))

        angle := 2f * Float.pi * percent
        expected := angle.sin * amplitude + offset
        verifyStatus(sw.out, sn(expected))
      }
    }
  }

}