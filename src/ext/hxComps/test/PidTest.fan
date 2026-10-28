//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Oct 2026  Jason Briggs  Creation
//

using xeto
using haystack

class PidTest : HxCompTest
{
  Void testDefaults()
  {
    Pid p := createComp("Pid")
    verifyEq(p.loopAction, PidAction.direct)
    verifyEq(p.disableAction, PidDisableAction.zero)
    verifyEq(p.proportionalConstant, 1f)
    verifyEq(p.integralConstant, 0f)
    verifyEq(p.derivativeConstant, 0f)
    verifyEq(p.bias, 50f)
    verifyEq(p.maximumOutput, 100f)
    verifyEq(p.minimumOutput, 0f)
    verifyEq(p.freq, 1sec)
  }

  Void testProportional()
  {
    Pid p := createComp("Pid")
    p.proportionalConstant = 10f

    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now
      cs.root.add(p)

      // unlinked inputs: no out
      cx.step(ts)
      verifyEq(p.out, null)

      // on setpoint: bias
      p.set("controlledVariable", sn(72))
      p.set("setpoint", sn(72))
      cx.step(ts+1sec)
      verifyEq(p.out, sn(50))

      // direct: 2 above setpoint raises out by Kp * 2
      p.set("controlledVariable", sn(74))
      cx.step(ts+2sec)
      verifyEq(p.out, sn(70))

      // reverse: the same error lowers it
      p.loopAction = PidAction.reverse
      cx.step(ts+3sec)
      verifyEq(p.out, sn(30))

      // held at the limits
      p.set("controlledVariable", sn(60))
      cx.step(ts+4sec)
      verifyEq(p.out, sn(100))
      p.set("controlledVariable", sn(90))
      cx.step(ts+5sec)
      verifyEq(p.out, sn(0))
    }
  }

  Void testIntegral()
  {
    // Ki 1 repeat/min: a steady error adds Kp * error again each minute
    Pid p := createComp("Pid")
    p.proportionalConstant = 2f
    p.integralConstant = 1f
    p.freq = 1min

    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now
      cs.root.add(p)
      p.set("controlledVariable", sn(75))
      p.set("setpoint", sn(72))

      cx.step(ts)
      verifyEq(p.out, sn(56))       // 50 + 2*3
      cx.step(ts+1min)
      verifyEq(p.out, sn(62))       // + 2*1*3
      cx.step(ts+2min)
      verifyEq(p.out, sn(68))
      cx.step(ts+3min)
      verifyEq(p.out, sn(74))
    }
  }

  Void testAntiWindup()
  {
    Pid p := createComp("Pid")
    p.proportionalConstant = 10f
    p.integralConstant = 1f
    p.freq = 1min

    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now
      cs.root.add(p)
      p.set("controlledVariable", sn(76))
      p.set("setpoint", sn(72))

      // 50 + 40 = 90, then held at 100: the integral stops at 1, the
      // amount that puts out at 100, where it would have reached 44
      cx.step(ts)
      verifyEq(p.out, sn(90))
      10.times |i| { cx.step(ts + 1min * (i+1)) }
      verifyEq(p.out, sn(100))

      // under setpoint it leaves the limit at once: no wound-up integral
      p.set("controlledVariable", sn(70))
      cx.step(ts+11min)
      verifyEq(p.out, sn(20))       // 50 + 10*(-2 + (1 - 2))
    }
  }

  Void testDerivative()
  {
    // Kd 60sec: an error rising 1 a minute adds Kp * 1
    Pid p := createComp("Pid")
    p.proportionalConstant = 1f
    p.derivativeConstant = 60f
    p.freq = 1min

    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now
      cs.root.add(p)
      p.set("controlledVariable", sn(72))
      p.set("setpoint", sn(72))
      cx.step(ts)
      verifyEq(p.out, sn(50))
      p.set("controlledVariable", sn(73))
      cx.step(ts+1min)
      verifyEq(p.out, sn(52))       // 50 + 1 + 1*60*(1/60)
      cx.step(ts+2min)
      verifyEq(p.out, sn(51))       // steady: the derivative is gone
    }
  }

  Void testRunsOnlyAtFreq()
  {
    Pid p := createComp("Pid")
    p.derivativeConstant = 60f
    p.freq = 1min

    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now
      cs.root.add(p)
      p.set("controlledVariable", sn(72))
      p.set("setpoint", sn(72))
      cx.step(ts)
      verifyEq(p.out, sn(50))

      // an input change does not run the loop before freq
      p.set("controlledVariable", sn(72.5f))
      cx.step(ts+1sec)
      verifyEq(p.out, sn(50))

      // the derivative is over the full minute
      cx.step(ts+1min)
      verifyEq(p.out, sn(51))       // 50 + 0.5 + 1*60*(0.5/60)
    }
  }

  Void testNaN()
  {
    Pid p := createComp("Pid")
    p.proportionalConstant = 2f
    p.integralConstant = 1f
    p.freq = 1min

    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now
      cs.root.add(p)
      p.set("controlledVariable", sn(75))
      p.set("setpoint", sn(72))
      cx.step(ts)
      cx.step(ts+1min)
      verifyEq(p.out, sn(62))

      // NaN or infinite input: out and the integral held, in fault
      p.set("controlledVariable", sn(Number.nan))
      cx.step(ts+2min)
      verifyEq(p.out, sn(62, Status.fault))
      p.set("setpoint", sn(Number.posInf))
      cx.step(ts+3min)
      verifyEq(p.out, sn(62, Status.fault))

      // recovers where it left off, without integrating across the gap
      p.set("controlledVariable", sn(75))
      p.set("setpoint", sn(72))
      cx.step(ts+4min)
      verifyEq(p.out, sn(62))       // 50 + 6 + 6 held, nothing integrated
      cx.step(ts+5min)
      verifyEq(p.out, sn(68))
    }
  }

  Void testIntegralOff()
  {
    // the integral does not accumulate while Ki is 0
    Pid p := createComp("Pid")
    p.freq = 1min

    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now
      cs.root.add(p)
      p.set("controlledVariable", sn(75))
      p.set("setpoint", sn(72))
      cx.step(ts)
      10.times |i| { cx.step(ts + 1min * (i+1)) }
      verifyEq(p.out, sn(53))

      p.integralConstant = 0.1f
      cx.step(ts+11min)
      verifyStatus(sn(53.3f), p.out)  // only this minute: 1*0.1*3
    }
  }

  Void testGainChange()
  {
    // changing Kp or Ki does not bump out
    Pid p := createComp("Pid")
    p.proportionalConstant = 2f
    p.integralConstant = 1f
    p.freq = 1min

    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now
      cs.root.add(p)
      p.set("controlledVariable", sn(73))
      p.set("setpoint", sn(72))
      cx.step(ts)
      5.times |i| { cx.step(ts + 1min * (i+1)) }
      verifyEq(p.out, sn(62))       // 50 + 2 + 5*2

      // at setpoint only the integral is left
      p.set("controlledVariable", sn(72))
      cx.step(ts+6min)
      verifyEq(p.out, sn(60))

      p.proportionalConstant = 4f
      cx.step(ts+7min)
      verifyEq(p.out, sn(60))
      p.integralConstant = 3f
      cx.step(ts+8min)
      verifyEq(p.out, sn(60))
    }
  }

  Void testEnableAndStatus()
  {
    Pid p := createComp("Pid")
    p.proportionalConstant = 2f
    p.integralConstant = 1f
    p.freq = 1min

    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now
      cs.root.add(p)
      p.set("controlledVariable", sn(75))
      p.set("setpoint", sn(72))
      cx.step(ts)
      cx.step(ts+1min)
      verifyEq(p.out, sn(62))

      // disabled: out is zero by default
      p.set("loopEnable", sb(false))
      cx.step(ts+2min)
      verifyEq(p.out, sn(0))

      // enabled again: resumes from zero
      p.set("loopEnable", sb(true))
      cx.step(ts+3min)
      verifyEq(p.out, sn(6))        // 0 + 2*3
      cx.step(ts+4min)
      verifyEq(p.out, sn(12))       // + 2*1*3

      // an invalid loopEnable disables, and its status is propagated
      p.set("loopEnable", sb(true, Status.down))
      cx.step(ts+5min)
      verifyEq(p.out, sn(0, Status.down))
      p.set("loopEnable", null)
      cx.step(ts+6min)
      verifyEq(p.out, sn(6))

      // an input in fault: out held, fault carried
      p.set("controlledVariable", sn(80, Status.fault))
      cx.step(ts+7min)
      verifyEq(p.out, sn(6, Status.fault))

      // an overridden input still runs, and says so; nothing is
      // integrated across the fault
      p.set("controlledVariable", sn(75, Status.overridden))
      cx.step(ts+8min)
      verifyEq(p.out, sn(6, Status.overridden))
      cx.step(ts+9min)
      verifyEq(p.out, sn(12, Status.overridden))
    }
  }

  Void testDisableAction()
  {
    verifyDisableAction(PidDisableAction.zero,     0f,   10f)
    verifyDisableAction(PidDisableAction.hold,     62f,  68f)
    verifyDisableAction(PidDisableAction.minValue, 10f,  16f)
    verifyDisableAction(PidDisableAction.maxValue, 100f, 100f)
  }

  private Void verifyDisableAction(PidDisableAction action, Float disabled, Float resumed)
  {
    Pid p := createComp("Pid")
    p.proportionalConstant = 2f
    p.integralConstant = 1f
    p.minimumOutput = 10f
    p.disableAction = action
    p.freq = 1min

    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now
      cs.root.add(p)
      p.set("controlledVariable", sn(75))
      p.set("setpoint", sn(72))
      cx.step(ts)
      cx.step(ts+1min)
      verifyEq(p.out, sn(62))

      p.set("loopEnable", sb(false))
      cx.step(ts+2min)
      verifyEq(p.out, sn(disabled))

      // resumes from the disabled value plus the proportional term,
      // held between the limits
      p.set("loopEnable", sb(true))
      cx.step(ts+3min)
      verifyEq(p.out, sn(resumed))
    }
    cs.root.remove(p.name)
  }
}
