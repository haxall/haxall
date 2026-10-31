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

class AssertTest : HxCompTest
{
  static const DateTime T := DateTime.fromJava(1_760_486_400_000, TimeZone.utc)

  ** A fall logs a warning and the recovery after it logs at info level;
  ** a first false logs, as CDL checks at the start
  Void testLog()
  {
    sim("supply fan proven") |c, cx|
    {
      [false, true, true, false].each |v, i| { set(cx, c, sb(v), T + Duration(i * 2hr.ticks)) }
      pre := "Assert @${c.id}: assertion"
      verifyEq(logged.map |r->Str| { "$r.level $r.msg" }, [
        "warn $pre failed: supply fan proven (logged at most once per 1hr)",
        "info $pre holds again: supply fan proven",
        "warn $pre failed: supply fan proven (logged at most once per 1hr)",
      ])
      verifyEq(c.numFailed, 2)
    }
  }

  ** A chattering in logs at most once an hour, and the falls held back
  ** log with their count when the hour passes, though in has recovered
  Void testRateLimit()
  {
    sim("x") |c, cx|
    {
      [false, true, false, true, false, true].each |v, i| { set(cx, c, sb(v), T + Duration(i * 1sec.ticks)) }
      verifyEq(logged.map |r->Str| { "$r.level" }, ["warn", "info"])
      verifyEq(c.numFailed, 3)
      cx.step(T+1hr)
      recs := logged
      verifyEq(recs.size, 1)
      verify(recs.first.msg.contains("2 falls not logged"), recs.first.msg)
    }
  }

  ** The hour runs on the comp's own clock, where a step back is no time
  Void testClockBack()
  {
    sim("x") |c, cx|
    {
      set(cx, c, sb(false), T)
      set(cx, c, sb(true), T+1sec)
      set(cx, c, sb(false), T+2sec)
      set(cx, c, sb(false), T-1hr)
      verifyEq(logged.size, 2)
      cx.step(T-3sec);  verifyEq(logged.size, 0)
      cx.step(T-2sec);  verifyEq(logged.size, 1)
    }
  }

  ** out is the value and status of a valid in, and a false in is not a
  ** fault.  A null in sets out to null, an invalid in is not checked and
  ** holds out with its status, a first true logs nothing, a fall is
  ** against the last valid in, and an empty message logs a default text.
  Void testOut()
  {
    sim("") |c, cx|
    {
      set(cx, c, null, T);                         verifyNull(c.out)
      set(cx, c, sb(false, Status.down), T+1sec);  verifyNull(c.out)
      set(cx, c, sb(true), T+2sec);                verifyEq(c.out, sb(true))
      set(cx, c, sb(false, Status.down), T+3sec);  verifyEq(c.out, sb(true, Status.down))
      set(cx, c, null, T+4sec);                    verifyNull(c.out)
      set(cx, c, sb(false), T+5sec);               verifyEq(c.out, sb(false))
      set(cx, c, sb(true, Status.overridden), T+6sec)
      verifyEq(c.out, sb(true, Status.overridden))
      recs := logged
      verifyEq(recs.map |r->Str| { "$r.level" }, ["warn", "info"])
      verify(recs.first.msg.contains("assertion failed: in is false"), recs.first.msg)
      verifyEq(c.numFailed, 1)
    }
  }

  ** Mount an Assert at T with the hxComps log captured, and run f
  private Void sim(Str message, |Assert, SimulatedCompContext| f)
  {
    Assert c := createComp("Assert")
    c.message = message
    Actor.locals["hxComps.assertTest"] = LogRec[,]
    Log.addHandler(handler)
    try
      SimulatedCompContext(cs, T).asCur |cx| { cs.root.add(c); f(c, cx) }
    finally
      Log.removeHandler(handler)
  }

  private static const |LogRec| handler := |LogRec r|
  {
    if (r.logName == "hxComps") (Actor.locals["hxComps.assertTest"] as LogRec[])?.add(r)
  }

  ** The records the hxComps log took since the last call
  private LogRec[] logged()
  {
    acc := (LogRec[])Actor.locals["hxComps.assertTest"]
    recs := acc.dup
    acc.clear
    return recs
  }

  private Void set(SimulatedCompContext cx, Assert c, StatusBool? v, DateTime ts)
  {
    c.set("in", v)
    cx.step(ts)
  }
}
