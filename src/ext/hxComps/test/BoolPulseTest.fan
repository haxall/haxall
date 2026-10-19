//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

class BoolPulseTest : HxCompTest
{
  ** A whole day after 1970 UTC, so on the grid of every period used here
  static const DateTime T := DateTime.fromJava(1_760_486_400_000, TimeZone.utc)

  ** True for width of each period.  An edge takes effect on the first
  ** cycle at or after it, the comp asks to execute at its next edge, and a
  ** window between two executes is missed.
  Void testPulse()
  {
    pulse(10sec, 0.25f, 0sec, T) |c, cx|
    {
      verifyStep(cx, c, T,          true);   verifyEq(c.onExecuteFreq, 2.5sec)
      verifyStep(cx, c, T+2.5sec,   false);  verifyEq(c.onExecuteFreq, 7.5sec)
      verifyStep(cx, c, T+10.5sec,  true)
      verifyStep(cx, c, T+13sec,    false)
      verifyStep(cx, c, T+20sec,    true)
      verifyStep(cx, c, T+33sec,    false)
    }
  }

  ** Rises are on the UTC grid plus shift mod period, wherever it starts
  Void testGrid()
  {
    [3sec, 13sec, -7sec].each |shift|
    {
      pulse(10sec, 0.2f, shift, T+4sec) |c, cx|
      {
        verifyStep(cx, c, T+4sec,   true)
        verifyStep(cx, c, T+5sec,   false)
        verifyStep(cx, c, T+13sec,  true)
      }
    }
  }

  ** A clock that moves back holds out.  The executes are forced, since a
  ** step back counts as no time on the timer.
  Void testClockBack()
  {
    pulse(10sec, 0.2f, 0sec, T) |c, cx|
    {
      verifyStep(cx, c, T+5sec, false)
      c.execute; verifyStep(cx, c, T+1sec, false)
      c.execute; verifyStep(cx, c, T+10sec, true)
      c.execute; verifyStep(cx, c, T+6sec, true)
    }
  }

  ** A bad period or width faults, a fixed one resumes on the grid, and a
  ** width of 1 stays true
  Void testFault()
  {
    pulse(0sec, 0.5f, 0sec, T) |c, cx|
    {
      cx.step(T);       verifyEq(c.out, sb(false, Status.fault))
      c.period = 10sec
      cx.step(T+2sec);  verifyEq(c.out, sb(true))
      [0f, 2f, Float.nan].each |w|
      {
        c.width = w
        cx.step(T+3sec);  verifyEq(c.out, sb(false, Status.fault), "width $w")
      }
      c.width = 0.5f
      verifyStep(cx, c, T+4sec, true)
      verifyStep(cx, c, T+5sec, false)
      c.width = 1f
      verifyStep(cx, c, T+6sec, true)
      verifyStep(cx, c, T+10sec, true)
    }
  }

  ** Rises on the cycles a SampleTrigger of equal period and shift fires
  Void testRisesWithTrigger()
  {
    pulse(10sec, 0.3f, 2sec, T) |c, cx|
    {
      SampleTrigger st := createComp("SampleTrigger")
      st.period = 10sec; st.shift = 2sec
      cs.root.add(st)
      Bool? last := null
      rises := 0
      [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23].each |s|
      {
        cx.step(T + Duration(s * 1sec.ticks))
        rise := last == false && c.out.val
        if (rise) rises++
        if (s > 1) verifyEq(st.out.val, rise, "T+$s")
        last = c.out.val
      }
      verifyEq(rises, 3)
    }
  }

  ** Linked into a NumberSwitch it gives the CDL Reals.Sources.Pulse
  Void testRealPulse()
  {
    pulse(10sec, 0.5f, 0sec, T) |c, cx|
    {
      sw := createComp("NumberSwitch")
      cs.root.add(sw)
      sw.set("inTrue", sn(3)); sw.set("inFalse", sn(1))
      sw.set("links", sw.links.add("inSwitch", Etc.link(c.id, "out")))
      cx.step(T);       verifyEq(sw.get("out"), sn(3))
      cx.step(T+5sec);  verifyEq(sw.get("out"), sn(1))
    }
  }

  private Void pulse(Duration period, Float width, Duration shift, DateTime ts, |BoolPulse, SimulatedCompContext| f)
  {
    BoolPulse c := createComp("BoolPulse")
    c.period = period
    c.width = width
    c.shift = shift
    SimulatedCompContext(cs, ts).asCur |cx|
    {
      cs.root.add(c)
      f(c, cx)
      cs.root.remove(c.name)
    }
  }

  private Void verifyStep(SimulatedCompContext cx, BoolPulse c, DateTime ts, Bool expected)
  {
    cx.step(ts)
    verifyEq(c.out, sb(expected), "out at $ts")
  }
}
