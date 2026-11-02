//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using concurrent
using xeto
using haystack

class SampleTriggerTest : HxCompTest
{
  ** 2025-10-15T00:00:00Z: a whole number of days after 1 Jan 1970 UTC,
  ** and 1 sec past a multiple of 7 sec
  static const DateTime T := DateTime.fromJava(1_760_486_400_000, TimeZone.utc)

  ** Instants sit on the UTC epoch grid, each pulses for one execute on
  ** the first cycle at or after it, a late cycle pulses once, and a
  ** clock moved back fires no instant again
  Void testPulse()
  {
    c := newTrigger(7sec)
    sim(c) |cx|
    {
      verifyStep(cx, c, 0, false)
      verifyStep(cx, c, 6.5f, true)
      verifyStep(cx, c, 7, false)
      verifyStep(cx, c, 13, true)
      verifyStep(cx, c, 14, false)
      verifyStep(cx, c, 30, true)
      verifyStep(cx, c, 31, false)
      c.execute; verifyStep(cx, c, 15, false)
      c.execute; verifyStep(cx, c, 34, true)
      verifyEq(c.skipped, 1)
    }
  }

  ** Instants on consecutive cycles each pulse, and a period below the
  ** cycle counts skips
  Void testConsecutiveCycles()
  {
    [1sec: 0, 500ms: 5].each |skips, p|
    {
      c := newTrigger(p)
      sim(c) |cx| { verifyEq(pulses(cx, c, 0, 5), [0, 1, 2, 3, 4, 5]) }
      verifyEq(c.skipped, skips)
    }
  }

  ** Only mod(shift, period) counts
  Void testShift()
  {
    [3sec, 13sec, -7sec].each |shift|
    {
      c := newTrigger(10sec, shift)
      sim(c) |cx| { verifyEq(pulses(cx, c, 0, 24), [3, 13, 23], "$shift") }
    }
  }

  ** A period of 0 or less is a fault, and a fixed period runs on the grid
  Void testPeriodFault()
  {
    c := newTrigger(0sec)
    sim(c) |cx|
    {
      verifyStep(cx, c, 0, false, Status.fault)
      c.period = -10sec
      verifyStep(cx, c, 1, false, Status.fault)
      c.period = 10sec
      verifyStep(cx, c, 5, false)
      verifyStep(cx, c, 10, true)
    }
  }

  ** Fires on consecutive cycles log one warning a run, at most hourly,
  ** and the end of a run that logged
  Void testLogsConsecutiveFires()
  {
    c := newTrigger(1sec)
    sim(c) |cx|
    {
      recs := capture |->| { pulses(cx, c, 0, 9) }
      verifyEq(recs.size, 1)
      verifyEq(recs[0].level, LogLevel.warn)
      verify(recs[0].msg.startsWith("SampleTrigger @${c.id}: fires on consecutive cycles"))
      c.period = 3sec
      recs = capture |->| { verifyStep(cx, c, 10, false) }
      verifyEq(recs.size, 1)
      verifyEq(recs[0].msg, "SampleTrigger @${c.id}: consecutive fires ended after 10 fires")
      c.period = 1sec
      recs = capture |->| { pulses(cx, c, 20, 25) }
      verifyEq(recs.size, 0)
    }
  }

  private SampleTrigger newTrigger(Duration period, Duration shift := 0sec)
  {
    c := (SampleTrigger)createComp("SampleTrigger")
    c.period = period
    c.shift = shift
    return c
  }

  private Void sim(Comp c, |SimulatedCompContext| f)
  {
    SimulatedCompContext(cs, T).asCur |cx| { cs.root.add(c); f(cx); cs.root.remove(c.name) }
  }

  ** Step 1 sec cycles over T+from..T+to and return the seconds out was true
  private Int[] pulses(SimulatedCompContext cx, SampleTrigger c, Int from, Int to)
  {
    (from..to).toList.findAll |s| { cx.step(T + Duration(s * 1sec.ticks)); return c.out.val }
  }

  private Void verifyStep(SimulatedCompContext cx, SampleTrigger c, Num s, Bool v, Status status := Status.ok)
  {
    cx.step(T + Duration((s.toFloat * 1e9f).toInt))
    verifyEq(c.out, StatusBool(v, status), "T+$s")
  }

  ** Run f and return what the hxComps log took meanwhile
  private LogRec[] capture(|->| f)
  {
    Actor.locals["hxComps.test.recs"] = LogRec[,]
    h := |LogRec r| { if (r.logName == "hxComps") (Actor.locals["hxComps.test.recs"] as LogRec[])?.add(r) }
    Log.addHandler(h)
    try f()
    finally Log.removeHandler(h)
    return Actor.locals.remove("hxComps.test.recs")
  }
}
