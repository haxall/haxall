//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Oct 2026  Lincoln Harmer  Creation
//

using concurrent
using xeto
using haystack

class VariablePulseTest : HxCompTest
{
  static const DateTime T := DateTime.fromJava(1_760_486_400_000, TimeZone.utc)

  ** The periods run from the first execute, and out is true from each
  ** start for in times the run period
  Void testWidth()
  {
    // the run period is 100s, as 2.02 times minHold 1s is less.  The first
    // execute at 30s starts the periods, and out is true for 0.75 times
    // 100s, so from 30s up to 105s and again from 130s.  Each segment is
    // longer than minHold, so the hold changes nothing.
    c := newPulse(100sec, 1sec)
    sim(c, T+30sec) |cx|
    {
      c.set("in", sn(0.75f))
      acc := Int[,]
      (30..140).each |s| { if (stepVal(cx, c, s * 1000)) acc.add(s) }
      verifyEq(acc, (30..104).toList.addAll((130..140).toList))
    }
  }

  ** A move of in by deltaU or less changes the width in the running
  ** period, and a larger move or an edit of period starts them again
  Void testMove()
  {
    VariablePulse c := createComp("VariablePulse")
    verifyEq(c.period, 1min)
    verifyEq(c.deltaU, 0.01f)
    verifyNull(c.minHold)
    c.period = 10sec
    c.minHold = 100ms
    c.deltaU = 0.25f
    sim(c, T) |cx|
    {
      // the run period is 10s, and minHold 100ms is shorter than every
      // segment here.  0s: the periods start, and out is true for 0.5
      // times 10s, so it falls at 5s
      c.set("in", sn(0.5f))
      verifyEq(stepVal(cx, c, 0), true)
      verifyEq(stepVal(cx, c, 6_000), false)
      // 7s: a move of 0.25 is not more than deltaU, so the width in the
      // running period is 7.5s and out is true again until 7.5s
      c.set("in", sn(0.75f))
      verifyEq(stepVal(cx, c, 7_000), true)
      verifyEq(stepVal(cx, c, 8_000), false)
      // 9s: a move of 0.375 from 0.5 starts the periods again, with a
      // width of 1.25s, so out falls at 10.25s and rises at 19s
      c.set("in", sn(0.125f))
      verifyEq(stepVal(cx, c, 9_000), true)
      verifyEq(stepVal(cx, c, 10_250), false)
      verifyEq(stepVal(cx, c, 19_000), true)
      // 21s: the edit starts the periods again, with a run period of 20s
      // and a width of 2.5s, so out is true from 21s up to 23.5s
      c.period = 20sec
      verifyEq(stepVal(cx, c, 21_000), true)
      verifyEq(stepVal(cx, c, 23_000), true)
      verifyEq(stepVal(cx, c, 23_500), false)
    }
  }

  ** A pulse wholly between two executes is still held for minHold
  Void testPulseBetweenExecutes()
  {
    // the run period is 100s and the width 0.02 times 100s, 2s.  The rise
    // at 0s is held for minHold 5s, so out falls at 5s.  The pulse due
    // from 100s to 102s falls between the executes at 99.5s and 103s, and
    // its rise at 100s is held to 105s.
    c := newPulse(100sec, 5sec)
    sim(c, T) |cx|
    {
      c.set("in", sn(0.02f))
      verifyEq(stepVal(cx, c, 0), true)
      verifyEq(stepVal(cx, c, 99_500), false)
      verifyEq(stepVal(cx, c, 103_000), true)
      verifyEq(stepVal(cx, c, 104_900), true)
      verifyEq(stepVal(cx, c, 105_000), false)
    }
  }

  ** A period under 2 times minHold warns once and runs at 2.02 times
  Void testShortPeriod()
  {
    // period 15s is under 2 times minHold 10s, so the run period is 2.02
    // times 10s, 20.2s, and the width 0.5 times 20.2s, 10.1s.  Both
    // segments are longer than the hold.
    c := newPulse(15sec, 10sec)
    recs := capture |->|
    {
      sim(c, T) |cx|
      {
        c.set("in", sn(0.5f))
        verifyEq(stepVal(cx, c, 0), true)
        verifyEq(stepVal(cx, c, 10_100), false)
        verifyEq(stepVal(cx, c, 20_100), false)
        verifyEq(stepVal(cx, c, 20_200), true)
      }
    }
    verifyEq(recs.size, 1)
    verifyEq(recs.first.level, LogLevel.warn)
  }

  ** A null minHold is 0.01 times period
  Void testDefaultMinHold()
  {
    // minHold is 0.01 times 100s, 1s.  The width is 0.005 times 100s,
    // 0.5s, so the rise at 0s is held and out falls at 1s.
    c := newPulse(100sec, null)
    sim(c, T) |cx|
    {
      c.set("in", sn(0.005f))
      verifyEq(stepVal(cx, c, 0), true)
      verifyEq(stepVal(cx, c, 900), true)
      verifyEq(stepVal(cx, c, 1000), false)
    }
  }

  ** A bad parameter or a NaN in faults and holds out, false before the
  ** first value.  An invalid in holds out, and a null in sets it null.
  Void testStatus()
  {
    // deltaU 0 and 0.6, minHold 0, period 0 with a null minHold, and a run
    // period just under 1ms
    Obj?[][] bad := [[10sec, 0f, 1sec], [10sec, 0.6f, 1sec], [10sec, 0.01f, 0sec],
                     [0sec, 0.01f, null], [Duration(999_999), 0.01f, null]]
    bad.each |r|
    {
      c := newPulse(r[0], r[2], r[1])
      sim(c, T) |cx| { c.set("in", sn(0.5f)); cx.step(T); verifyOut(c, false, Status.fault, r) }
    }

    // the run period is 10s and the width 5s
    c := newPulse(10sec, 1sec)
    sim(c, T) |cx|
    {
      c.set("in", sn(0.5f))
      verifyEq(stepVal(cx, c, 0), true)
      // 1s: a NaN faults; 2s: a bad deltaU faults with an invalid in
      c.set("in", sn(Float.nan))
      cx.step(T + 1sec)
      verifyOut(c, true, Status.fault)
      c.deltaU = 0.6f
      c.set("in", sn(0.5f, Status.down))
      cx.step(T + 2sec)
      verifyOut(c, true, Status.down.set(Status.fault))
      // 6s: the state is kept and the periods ran on, so out fell at 5s
      c.deltaU = 0.01f
      c.set("in", sn(0.5f))
      verifyEq(stepVal(cx, c, 6_000), false)
      // 7s: an invalid in holds out; 8s: a null sets it null; 9s: an
      // invalid in holds the null
      c.set("in", sn(1f, Status.down))
      cx.step(T + 7sec)
      verifyOut(c, false, Status.down)
      c.set("in", null)
      cx.step(T + 8sec)
      verifyNull(c.out)
      c.set("in", sn(1f, Status.down))
      cx.step(T + 9sec)
      verifyNull(c.out)
      // 10s: in is 0.5 still, as the invalid values kept the state, and a
      // period starts
      c.set("in", sn(0.5f))
      verifyEq(stepVal(cx, c, 10_000), true)
    }
  }

  ** A clock stepped back counts as no time, so the phase runs on
  Void testStepBack()
  {
    // the run period is 10s and the width 5s.  The periods start at 7s;
    // the step back adds no time, so out falls 5s after it and rises
    // again 10s after it.
    c := newPulse(10sec, 1sec)
    sim(c, T) |cx|
    {
      c.set("in", sn(0.5f))
      verifyEq(stepVal(cx, c, 7_000), true)
      c.execute
      back := T + 7sec - 1hr
      cx.step(back)
      verifyOut(c, true, Status.ok)
      cx.step(back + 5sec)
      verifyOut(c, false, Status.ok)
      cx.step(back + 10sec)
      verifyOut(c, true, Status.ok)
    }
  }

  private VariablePulse newPulse(Duration period, Duration? minHold, Float deltaU := 0.01f)
  {
    c := (VariablePulse)createComp("VariablePulse")
    c.period = period
    c.minHold = minHold
    c.deltaU = deltaU
    return c
  }

  private Void sim(Comp c, DateTime ts, |SimulatedCompContext| f)
  {
    SimulatedCompContext(cs, ts).asCur |cx|
    {
      cs.root.add(c)
      f(cx)
      cs.root.remove(c.name)
    }
  }

  private Bool stepVal(SimulatedCompContext cx, VariablePulse c, Int ms)
  {
    cx.step(T + Duration(ms * 1ms.ticks))
    verifyNotNull(c.out, "out at $ms")
    verifyEq(c.out.status, Status.ok, "status at $ms")
    return c.out.val
  }

  private Void verifyOut(VariablePulse c, Bool expected, Status status, Obj? at := null)
  {
    verifyNotNull(c.out, "out at $at")
    verifyEq(c.out.val, expected, "out at $at")
    verifyEq(c.out.status, status, "status at $at")
  }

  private LogRec[] capture(|->| f)
  {
    acc := LogRec[,]
    Actor.locals["hxComps.variablePulseTest"] = acc
    handler := |LogRec r| { if (r.logName == "hxComps" && r.msg.startsWith("VariablePulse")) (Actor.locals["hxComps.variablePulseTest"] as LogRec[])?.add(r) }
    Log.addHandler(handler)
    try f()
    finally { Log.removeHandler(handler); Actor.locals.remove("hxComps.variablePulseTest") }
    return acc
  }
}
