//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

class StageTest : HxCompTest
{
  static const DateTime T := DateTime.fromJava(1_760_486_400_000, TimeZone.utc)

  ** Up above threshold + h and down below threshold - h, strictly; at
  ** stage n the thresholds meet, so out leaves n with no hysteresis
  Void testStages()
  {
    stage(4, 0sec, 0.0625f) |c, cx|
    {
      verifyStep(cx, c, T,       0f,      0)
      verifyStep(cx, c, T+1sec,  0.0625f, 0)
      verifyStep(cx, c, T+2sec,  0.07f,   1)
      verifyStep(cx, c, T+3sec,  0.3125f, 1)
      verifyStep(cx, c, T+4sec,  0.32f,   2)
      verifyStep(cx, c, T+5sec,  0.1875f, 2)
      verifyStep(cx, c, T+6sec,  0.18f,   1)
      verifyStep(cx, c, T+7sec,  0.8f,    4)
      verifyStep(cx, c, T+8sec,  0.7f,    3)
    }
  }

  ** The first execute sets initVal and starts the hold, and the comp asks
  ** to execute when the hold ends.  A step back counts as no time, so the
  ** hold does not end early.
  Void testHold()
  {
    stage(4, 10sec, null) |c, cx|
    {
      c.initVal = 3
      verifyStep(cx, c, T, 0.6f, 3);       verifyEq(c.onExecuteFreq, 10sec)
      verifyStep(cx, c, T+4sec, 0.1f, 3);  verifyEq(c.onExecuteFreq, 6sec)
      cx.step(T+10sec);  verifyEq(c.out, sn(1))
      verifyStep(cx, c, T+20sec, 0.6f, 3)
      verifyStep(cx, c, T+5sec, 0.1f, 3)
      cx.step(T+14sec);  verifyEq(c.out, sn(3))
      cx.step(T+15sec);  verifyEq(c.out, sn(1))
    }
  }

  ** A change of n lowers out to n and does not restart the hold
  Void testNChange()
  {
    stage(4, 1sec, null) |c, cx|
    {
      verifyStep(cx, c, T, 0.6f, 0)
      cx.step(T+1sec);    verifyEq(c.out, sn(3))
      c.n = 2
      cx.step(T+1.5sec);  verifyEq(c.out, sn(2))
      c.n = 4
      cx.step(T+1.7sec);  verifyEq(c.out, sn(2))
      cx.step(T+2sec);    verifyEq(c.out, sn(3))
    }
  }

  ** At a hold of 0, out does not stick: not when in starts more than h
  ** from 0, not within h of the next threshold, and not at stage n or 0
  Void testZeroHold()
  {
    stage(4, 0sec, 0.0625f) |c, cx|
    {
      verifyStep(cx, c, T,       0.6f,  0)
      verifyStep(cx, c, T+1sec,  0.6f,  3)
      verifyStep(cx, c, T+2sec,  0.3f,  2)
      verifyStep(cx, c, T+3sec,  0.7f,  3)
      verifyStep(cx, c, T+4sec,  0.9f,  4)
      verifyStep(cx, c, T+5sec,  -0.5f, 0)
      verifyStep(cx, c, T+6sec,  0.5f,  3)
    }
  }

  ** A null in sets out to null, an invalid in holds out with its status,
  ** and a NaN in holds out with status fault
  Void testNullInvalid()
  {
    stage(4, 0sec, null) |c, cx|
    {
      verifyStep(cx, c, T,       null, null)
      verifyStep(cx, c, T+1sec,  0f,   0)
      verifyStep(cx, c, T+2sec,  0.6f, 3)
      verifyStep(cx, c, T+3sec,  sn(0.1f, Status.down), 3, Status.down)
      verifyStep(cx, c, T+4sec,  sn(Float.nan), 3, Status.fault)
      verifyStep(cx, c, T+5sec,  null, null)
      verifyStep(cx, c, T+6sec,  0.1f, 1)
    }
  }

  ** A null h is 0.02/n, 0.01 for n = 2.  An h outside 0.001/n to 0.5/n,
  ** an n below 1 or a negative holdDuration faults and holds out.
  Void testFault()
  {
    stage(2, 0sec, null) |c, cx|
    {
      verifyStep(cx, c, T,       0.005f, 0)
      verifyStep(cx, c, T+1sec,  0.015f, 1)
      verifyStep(cx, c, T+2sec,  0.505f, 1)
      verifyStep(cx, c, T+3sec,  0.515f, 2)
      c.h = 0.3f
      verifyStep(cx, c, T+4sec, 0.1f, 2, Status.fault)
      c.h = null
      c.n = 0
      verifyStep(cx, c, T+5sec, 0.1f, 2, Status.fault)
      c.n = 2
      c.holdDuration = -1sec
      verifyStep(cx, c, T+6sec, 0.1f, 2, Status.fault)
      c.holdDuration = 0sec
      verifyStep(cx, c, T+7sec, 0.1f, 1)
    }
  }

  private Void stage(Int n, Duration hold, Float? h, |Stage, SimulatedCompContext| f)
  {
    Stage c := createComp("Stage")
    c.n = n
    c.holdDuration = hold
    c.h = h
    SimulatedCompContext(cs, T).asCur |cx|
    {
      cs.root.add(c)
      f(c, cx)
      cs.root.remove(c.name)
    }
  }

  private Void verifyStep(SimulatedCompContext cx, Stage c, DateTime ts, Obj? x, Int? expected, Status status := Status.ok)
  {
    c.set("in", x is Float ? sn(x) : x)
    cx.step(ts)
    verifyEq(c.out, expected == null ? null : sn(expected, status), "in $x at $ts")
  }
}
