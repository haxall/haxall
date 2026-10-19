//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

class FirstOrderHoldTest : HxCompTest
{
  ** 2025-10-15T00:00:00Z: a whole number of days after 1 Jan 1970 UTC
  static const DateTime T := DateTime.fromJava(1_760_486_400_000, TimeZone.utc)

  ** Until the first instant out is the first in.  From each instant out
  ** follows the line through the last two samples, one period late, with
  ** their merged status.  It is refreshed every second, and a late cycle
  ** takes the instant's time.
  Void testLine()
  {
    sim |c, cx|
    {
      stepIn(cx, c, sn(4, Status.alarm), 4);  verifyN(c, 4f, Status.alarm)
      stepIn(cx, c, 10, 8);                   verifyN(c, 4f, Status.alarm)
      verifyRun(cx, c, 9, 19, |Int s->Float?| { s <= 10 ? 4f : 4f + 0.6f * (s - 10).toFloat }, Status.alarm)
      verifyRun(cx, c, 20, 21, |Int s->Float?| { 10f })
      stepIn(cx, c, 0, 25);  verifyN(c, 10f)
      cx.step(T+30.5sec);    verifyN(c, 9.5f)
      cx.step(T+31.5sec);    verifyN(c, 8.5f)
    }
  }

  ** An invalid in holds out with its status, and an instant passed then
  ** takes the last sample again.  A NaN in holds out with fault, and a
  ** null in gives null.
  Void testNullInvalidNaN()
  {
    sim |c, cx|
    {
      stepIn(cx, c, 0, 0)
      stepIn(cx, c, 10, 5)
      cx.step(T+12sec);                         verifyN(c, 2f)
      stepIn(cx, c, sn(50, Status.stale), 13);  verifyN(c, 2f, Status.stale)
      cx.step(T+20sec);                         verifyN(c, 2f, Status.stale)
      stepIn(cx, c, 10, 21);                    verifyN(c, 10f)
      stepIn(cx, c, Float.nan, 22);             verifyN(c, 10f, Status.fault)
      stepIn(cx, c, null, 23);                  verifyN(c, null)
    }
  }

  ** A period change restarts the line where it is, flat
  Void testPeriodChange()
  {
    sim |c, cx|
    {
      stepIn(cx, c, 0, 0)
      stepIn(cx, c, 10, 5)
      verifyRun(cx, c, 10, 13, |Int s->Float?| { (s - 10).toFloat })
      c.period = 20sec
      verifyRun(cx, c, 14, 22, |Int s->Float?| { s < 20 ? 4f : 4f + 0.3f * (s - 20).toFloat })
    }
  }

  ** Mount a hold with a 10 sec period and run f at T
  private Void sim(|FirstOrderHold, SimulatedCompContext| f)
  {
    c := (FirstOrderHold)createComp("FirstOrderHold")
    c.period = 10sec
    SimulatedCompContext(cs, T).asCur |cx| { cs.root.add(c); f(c, cx); cs.root.remove(c.name) }
  }

  ** Set in (a number, a StatusNumber or null) and step to T plus s seconds
  private Void stepIn(SimulatedCompContext cx, Comp c, Obj? v, Int s)
  {
    c.set("in", v == null || v is StatusNumber ? v : sn(v))
    cx.step(T + Duration(s * 1sec.ticks))
  }

  ** Step 1 sec cycles from T+from to T+to and verify out on each
  private Void verifyRun(SimulatedCompContext cx, FirstOrderHold c, Int from, Int to, |Int->Float?| expected, Status status := Status.ok)
  {
    (from..to).each |s|
    {
      cx.step(T + Duration(s * 1sec.ticks))
      verifyN(c, expected(s), status, "T+$s")
    }
  }

  private Void verifyN(FirstOrderHold c, Float? v, Status status := Status.ok, Str msg := "")
  {
    if (v == null) { verifyNull(c.out, msg); return }
    verify(c.out.num.toFloat.approx(v), "$msg: ${c.out.num} != $v")
    verifyEq(c.out.status, status, msg)
  }
}
