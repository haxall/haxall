//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

class CdlPidTest : HxCompTest
{
  ** The defaults are the CDL defaults
  Void testDefaults()
  {
    CdlPid c := createComp("CdlPid")
    verifyEq(c.controllerType, PidControllerType.pi)
    verifyEq([c.k, c.r, c.yMax, c.yMin, c.ni, c.nd, c.xiStart, c.ydStart, c.yReset],
             [1f, 1f, 1f, 0f, 0.9f, 10f, 0f, 0f, 0f])
    verifyEq([c.ti, c.td, c.reverseActing], [0.5sec, 0.1sec, true])
    verifyNull(c.out)
  }

  ** P only: the error scaled by r, the gain and the limits
  Void testP()
  {
    sim(["controllerType":PidControllerType.p, "k":2f, "r":4f, "yMax":1.5f, "yMin":-0.5f]) |cx, c, t0|
    {
      verifyIn(cx, c, 10, 8, t0, 1f)
      verifyAt(cx, c, t0+1sec, 1f)
      verifyIn(cx, c, 10, 6, t0+2sec, 1.5f)
      verifyIn(cx, c, 10, 20, t0+3sec, -0.5f)
    }
  }

  ** The derivative gain is k*Td, not k
  Void testDerivativeGain()
  {
    sim(["controllerType":PidControllerType.pd, "k":2f, "td":500ms, "nd":5f]) |cx, c, t0|
    {
      verifyIn(cx, c, 0, 0, t0, 0f)
      verifyIn(cx, c, 1, 0, t0+100ms, 7f)
      verifyAt(cx, c, t0+200ms, 4.5f)
    }
  }

  ** reverseActing flips all three terms
  Void testReverseActing()
  {
    [true, false].each |rev|
    {
      sim(["controllerType":PidControllerType.pid, "ti":1sec, "td":1sec, "reverseActing":rev]) |cx, c, t0|
      {
        verifyIn(cx, c, 0, 0, t0, 0f)
        verifyIn(cx, c, 0, 1, t0+0.1sec, rev ? -6.1f : 6.1f)
      }
    }
  }

  ** While out is limited I settles at yMax - k*e + k*ni*e, and a long step stays stable
  Void testAntiWindup()
  {
    sim(["ti":1sec, "ni":1f, "yMax":1f, "yMin":0f]) |cx, c, t0|
    {
      verifyIn(cx, c, 2, 0, t0, 1f)
      (1..3).each |n| { verifyAt(cx, c, t0 + Duration(n * 10sec.ticks), 1f) }
      verifyIn(cx, c, -0.25f, 0, t0+31sec, 1330f/1331f - 0.5f)
    }
  }

  ** Equal limits give that value, and I settles at yMax - k*e + k*ni*e
  Void testEqualLimits()
  {
    sim(["yMax":0.5f, "yMin":0.5f]) |cx, c, t0|
    {
      verifyIn(cx, c, 1, 0, t0, 0.5f)
      (1..10).each |n| { verifyAt(cx, c, t0 + Duration(n * 10sec.ticks), 0.5f) }
      c.yMax = 10f
      c.yMin = -10f
      verifyIn(cx, c, 0, 0, t0+101sec, 0.4f)
    }
  }

  ** A rise of inReset sets I so out before the limits is yReset, 0 by default
  Void testReset()
  {
    sim(["ti":1sec, "xiStart":0.5f, "yMax":10f, "yMin":-10f]) |cx, c, t0|
    {
      c.set("inSetpoint", sn(1))
      c.set("inMeasurement", sn(0))
      verifyReset(cx, c, true, t0, 1.5f)
      verifyAt(cx, c, t0+1sec, 2.5f)
      verifyReset(cx, c, false, t0+2sec, 3.5f)
      verifyReset(cx, c, true, t0+3sec, 0f)
      verifyAt(cx, c, t0+4sec, 1f)
      verifyReset(cx, c, null, t0+5sec, 2f)
      verifyReset(cx, c, true, t0+6sec, 3f)
      c.yReset = 20f
      verifyReset(cx, c, false, t0+7sec, 4f)
      verifyReset(cx, c, true, t0+8sec, 10f)
    }
  }

  ** A stall, or an execute that does not compute, is a gap for D: D holds and its filter
  ** starts again from there.  I bounds a stall at 1min.
  Void testGaps()
  {
    [null, sn(0, Status.down)].each |me|
    {
      sim(["controllerType":PidControllerType.pid, "ti":1sec, "td":1sec, "nd":1f]) |cx, c, t0|
      {
        verifyIn(cx, c, 0, 0, t0, 0f)
        verifyIn(cx, c, 1, 0, t0+1sec, 2.5f)
        verifyIn(cx, c, 1, me, t0+2sec, me == null ? null : 2.5f, Status.down)
        verifyIn(cx, c, 1, 0, t0+3sec, 3.5f)
        verifyAt(cx, c, t0+4sec, 4.25f)
        verifyAt(cx, c, t0+1hr+4sec, 64.25f)
        verifyAt(cx, c, t0+1hr+5sec, 65.125f)
      }
    }
  }

  ** A null input nulls out, an invalid one holds it, both keep the state, and a NaN faults
  Void testNullInvalidAndNonFinite()
  {
    sim(["ti":1sec]) |cx, c, t0|
    {
      verifyIn(cx, c, null, 0, t0, null)
      verifyIn(cx, c, sn(1, Status.down), 0, t0+1sec, null)
      verifyIn(cx, c, 1, 0, t0+2sec, 1f)
      verifyAt(cx, c, t0+3sec, 2f)
      verifyIn(cx, c, null, 0, t0+4sec, null)
      verifyAt(cx, c, t0+6sec, null)
      verifyIn(cx, c, 1, 0, t0+7sec, 3f)
      verifyIn(cx, c, 1, null, t0+8sec, null)
      verifyIn(cx, c, 1, 0, t0+9sec, 4f)
      verifyIn(cx, c, sn(1, Status.stale), sn(0, Status.down), t0+10sec, 4f, Status.stale.set(Status.down))
      verifyIn(cx, c, 1, Float.nan, t0+11sec, 4f, Status.fault)
      verifyIn(cx, c, Float.posInf, 0, t0+12sec, 4f, Status.fault)
      verifyIn(cx, c, 1, 0, t0+13sec, 5f)
    }
    sim(["ti":1sec]) |cx, c, t0| { verifyIn(cx, c, Float.nan, 0, t0, Float.nan, Status.fault) }
  }

  ** These settings fault, each only for the terms the type uses, and so do inputs in two units
  Void testParamFaults()
  {
    [["p", ["yMin":1.5f, "yMax":1f]], ["p", ["k":9e-14f]], ["p", ["k":-1f]], ["p", ["r":0f]],
     ["pi", ["ti":0sec]], ["pi", ["ni":0f]], ["pi", ["xiStart":Float.nan]],
     ["pd", ["td":0sec]], ["pd", ["nd":0f]], ["pd", ["ydStart":Float.nan]]].each |row| { verifyParams(row, true) }
    [["p", ["k":1e-13f, "ti":0sec, "td":0sec, "yReset":Float.nan]],
     ["pi", ["td":0sec, "nd":0f]], ["pd", ["ti":0sec, "ni":0f]]].each |row| { verifyParams(row, false) }
    f := Unit("°F")
    sim(["controllerType":PidControllerType.p]) |cx, c, t0|
    {
      verifyIn(cx, c, Number(70f, f), Number(68f, f), t0, 2f)
      verifyIn(cx, c, Number(70f, f), Number(20f, Unit("°C")), t0+1sec, 2f, Status.fault)
      verifyIn(cx, c, Number(70f, f), 67, t0+2sec, 3f)
    }
  }

  ** An infinite output limit is no limit, while a NaN limit, crossed limits and equal infinite
  ** limits fault
  Void testInfiniteLimits()
  {
    [["p", ["yMax":Float.posInf]], ["pi", ["yMax":Float.posInf]], ["p", ["yMin":Float.negInf]],
     ["p", ["yMin":Float.negInf, "yMax":Float.posInf]],
     ["pid", ["yMin":Float.negInf, "yMax":Float.posInf]]].each |row| { verifyParams(row, false) }
    [["p", ["yMin":Float.nan]], ["p", ["yMax":Float.nan]],
     ["p", ["yMin":Float.posInf]], ["p", ["yMax":Float.negInf]],
     ["p", ["yMin":Float.posInf, "yMax":Float.posInf]], ["pi", ["yMin":Float.posInf, "yMax":Float.posInf]],
     ["p", ["yMin":Float.negInf, "yMax":Float.negInf]]].each |row| { verifyParams(row, true) }

    // out is not limited above, and PI winds up past where a finite limit would stop it
    sim(["controllerType":PidControllerType.p, "yMax":Float.posInf]) |cx, c, t0|
    {
      verifyIn(cx, c, 2e6f, 0, t0, 2e6f)
    }
    sim(["controllerType":PidControllerType.pi, "ti":1sec, "yMax":Float.posInf]) |cx, c, t0|
    {
      verifyIn(cx, c, 1, 0, t0, 1f)
      verifyIn(cx, c, 1, 0, t0+1sec, 2f)
      verifyIn(cx, c, 1, 0, t0+2sec, 3f)
    }
  }

  ** With yMax +INF, PI winds up past 1e6 and out keeps climbing to 7e,
  ** where e is 2^1021, so 7e is about 1.57e308.  Any finite stand-in for
  ** the limit below 7e fails this test.  A stand-in from 7e up to the
  ** largest float gives the same outs here.  The step that overflows
  ** faults and holds out.
  Void testInfiniteLimitClimbs()
  {
    sim(["controllerType":PidControllerType.pi, "ti":1sec, "yMax":Float.posInf]) |cx, c, t0|
    {
      verifyIn(cx, c, 1e6f, 0, t0, 1e6f)
      verifyIn(cx, c, 1e6f, 0, t0+1sec, 2e6f)
      verifyIn(cx, c, 1e6f, 0, t0+2sec, 3e6f)
      verifyIn(cx, c, 1e6f, 0, t0+3sec, 4e6f)
    }

    // an error of e = 2^1021 gives out (n+1)e on step n, exactly, until 8e
    // overflows
    e := Float.makeBits(0x7fc0_0000_0000_0000)
    sim(["controllerType":PidControllerType.pi, "ti":1sec, "yMax":Float.posInf]) |cx, c, t0|
    {
      (0..6).each |n| { verifyIn(cx, c, e, 0, t0 + Duration(n * 1sec.ticks), (n + 1).toFloat * e) }
      verifyIn(cx, c, e, 0, t0+7sec, 7f * e, Status.fault)
    }
  }

  ** With yMax +INF and yMin 0, out holds at 0 while the error is negative,
  ** and once the error turns positive it recovers on the same step, to the
  ** same values, as with a finite yMax: the anti-windup at yMin works
  ** whatever yMax is
  Void testInfiniteLimitAntiWindup()
  {
    inf := windDown(Float.posInf)
    fin := windDown(1e300f)
    verifyEq(inf.size, 23)
    (0..<20).each |i| { verifyEq(inf[i], 0f) }
    verify(inf[20] > 2e6f, "out ${inf[20]} on the first step back")
    verifyEq(inf, fin)
  }

  ** PI with yMin 0: 20 steps at an error of -1, then 3 at an error of 1e6,
  ** 1sec apart.  The outs.
  private Float[] windDown(Float yMax)
  {
    outs := Float[,]
    sim(["ti":1sec, "yMax":yMax, "yMin":0f]) |cx, c, t0|
    {
      (0..<23).each |i|
      {
        c.set("inSetpoint", sn(i < 20 ? -1f : 1e6f))
        c.set("inMeasurement", sn(0))
        cx.step(t0 + Duration(i * 1sec.ticks))
        verifyEq(c.out.status, Status.ok)
        outs.add(c.out.num.toFloat)
      }
    }
    return outs
  }

  ** Mount a CdlPid with output limits of 1e6 and -1e6, then params
  private Void sim(Str:Obj params, |SimulatedCompContext, CdlPid, DateTime| f)
  {
    CdlPid c := createComp("CdlPid")
    Str:Obj["yMax":1e6f, "yMin":-1e6f].setAll(params).each |v, n| { c.set(n, v) }
    SimulatedCompContext(cs).asCur |cx|
    {
      cs.root.add(c)
      f(cx, c, cx.now)
      cs.root.remove(c.name)
    }
  }

  ** Set the inputs, each a Num, a Number, a StatusNumber or null, then step to ts and verify
  private Void verifyIn(SimulatedCompContext cx, CdlPid c, Obj? sp, Obj? me, DateTime ts,
                        Float? out, Status status := Status.ok)
  {
    c.set("inSetpoint", sp == null || sp is StatusNumber ? sp : sn(sp))
    c.set("inMeasurement", me == null || me is StatusNumber ? me : sn(me))
    verifyAt(cx, c, ts, out, status)
  }

  private Void verifyReset(SimulatedCompContext cx, CdlPid c, Bool? reset, DateTime ts, Float out)
  {
    c.set("inReset", reset == null ? null : sb(reset))
    verifyAt(cx, c, ts, out)
  }

  ** One execute at an error of 1 with row, a type and its params: out is NaN with fault, or k
  private Void verifyParams(Obj[] row, Bool fault)
  {
    sim(row[1]) |cx, c, t0|
    {
      c.controllerType = PidControllerType.fromStr(row[0])
      verifyIn(cx, c, 1, 0, t0, fault ? Float.nan : c.k, fault ? Status.fault : Status.ok)
    }
  }

  ** Step to ts and verify out, NaN included, and its status; out has no unit
  private Void verifyAt(SimulatedCompContext cx, CdlPid c, DateTime ts, Float? out, Status status := Status.ok)
  {
    cx.step(ts)
    o := c.out
    if (out == null) return verifyNull(o)
    verifyEq(o.status, status)
    verifyEq(o.num.unit, null)
    v := o.num.toFloat
    verify(out.isNaN ? v.isNaN : (v - out).abs <= 1e-9f, "out $v, expected $out")
  }
}
