//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

class RampTest : HxCompTest
{
  Void testTriangle()
  {
    Ramp r := createComp("Ramp")
    verifyEq(r.waveform, RampWaveform.triangle)
    verifyEq(r.period, 30sec)
    verifyEq(r.amplitude, 50f)
    verifyEq(r.offset, 50f)

    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now

      // mount the comp and prime it
      cs.root.add(r)
      cx.step(ts)

      cx.step(ts+7.5sec)
      verifyEq(r.out, sn(50))

      cx.step(ts+15sec)
      verifyEq(r.out, sn(100))

      cx.step(ts+22.5sec)
      verifyEq(r.out, sn(50))

      cx.step(ts+30sec)
      verifyEq(r.out, sn(0))
    }
  }

  Void testSawtooth()
  {
    Ramp r := createComp("Ramp")
    r.waveform = RampWaveform.sawtooth
    verifyEq(r.waveform, RampWaveform.sawtooth)
    verifyEq(r.period, 30sec)
    verifyEq(r.amplitude, 50f)
    verifyEq(r.offset, 50f)

    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now

      // mount the comp and prime it
      cs.root.add(r)
      cx.step(ts)

      cx.step(ts+7.5sec)
      verifyEq(r.out, sn(25))

      cx.step(ts+15sec)
      verifyEq(r.out, sn(50))

      cx.step(ts+22.5sec)
      verifyEq(r.out, sn(75))

      cx.step(ts+30sec)
      verifyEq(r.out, sn(0))
    }
  }

  Void testInvertedSawtooth()
  {
    Ramp r := createComp("Ramp")
    r.waveform = RampWaveform.invertedSawtooth
    verifyEq(r.waveform, RampWaveform.invertedSawtooth)
    verifyEq(r.period, 30sec)
    verifyEq(r.amplitude, 50f)
    verifyEq(r.offset, 50f)

    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now

      // mount the comp and prime it
      cs.root.add(r)
      cx.step(ts)

      cx.step(ts+7.5sec)
      verifyEq(r.out, sn(75))

      cx.step(ts+15sec)
      verifyEq(r.out, sn(50))

      cx.step(ts+22.5sec)
      verifyEq(r.out, sn(25))

      cx.step(ts+30sec)
      verifyEq(r.out, sn(100))
    }
  }
}
