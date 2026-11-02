//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

class SamplerTest : HxCompTest
{
  ** 2025-10-15T00:00:00Z: a whole number of days after 1 Jan 1970 UTC
  static const DateTime T := DateTime.fromJava(1_760_486_400_000, TimeZone.utc)

  static const Str[] types := ["Sampler", "ZeroOrderHold"]

  ** The first in is sampled, then in on the first cycle at or after each
  ** instant.  A late cycle samples once, and a clock moved back takes no
  ** instant again.
  Void testSample()
  {
    types.each |type|
    {
      sim(type) |c, cx|
      {
        stepIn(cx, c, 1, 1);   verifyN(c, 1f)
        stepIn(cx, c, 2, 9);   verifyN(c, 1f)
        cx.step(T+10.5sec);    verifyN(c, 2f)
        stepIn(cx, c, 3, 35);  verifyN(c, 3f)
        stepIn(cx, c, 4, 36);  verifyN(c, 3f)
        stepIn(cx, c, 5, 20);  verifyN(c, 3f)
        stepIn(cx, c, 6, 40);  verifyN(c, 6f)
        verifyEq(c.skipped, 1)
      }
    }
  }

  ** A null in gives null, an invalid in holds out with its status, and
  ** an instant passed while in is either takes no sample
  Void testNullAndInvalid()
  {
    types.each |type|
    {
      sim(type) |c, cx|
      {
        stepIn(cx, c, 1, 1);                     verifyN(c, 1f)
        stepIn(cx, c, sn(2, Status.stale), 2);   verifyN(c, 1f, Status.stale)
        stepIn(cx, c, sn(3, Status.down), 10);   verifyN(c, 1f, Status.down)
        stepIn(cx, c, 4, 11);                    verifyN(c, 1f)
        stepIn(cx, c, null, 12);                 verifyN(c, null)
        cx.step(T+20sec);                        verifyN(c, null)
        stepIn(cx, c, 5, 21);                    verifyN(c, 1f)
      }
    }
  }

  ** A NaN in or a period below 1ms is a fault that holds out, and a fixed
  ** period starts the clock again
  Void testFault()
  {
    types.each |type|
    {
      sim(type) |c, cx|
      {
        stepIn(cx, c, 1, 1);                     verifyN(c, 1f)
        stepIn(cx, c, Float.nan, 2);             verifyN(c, 1f, Status.fault)
        c.period = 0.5ms
        stepIn(cx, c, sn(2, Status.alarm), 3);   verifyN(c, 1f, Status.alarm.set(Status.fault))
        c.period = 10sec
        stepIn(cx, c, 3, 4);                     verifyN(c, 1f)
        cx.step(T+10sec);                        verifyN(c, 3f)
      }
    }
  }

  ** Mount a comp of type with a 10 sec period and run f at T
  private Void sim(Str type, |SampledComp, SimulatedCompContext| f)
  {
    c := (SampledComp)createComp(type)
    c.period = 10sec
    SimulatedCompContext(cs, T).asCur |cx| { cs.root.add(c); f(c, cx); cs.root.remove(c.name) }
  }

  ** Set in (a number, a StatusNumber or null) and step to T plus s seconds
  private Void stepIn(SimulatedCompContext cx, Comp c, Obj? v, Int s)
  {
    c.set("in", v == null || v is StatusNumber ? v : sn(v))
    cx.step(T + Duration(s * 1sec.ticks))
  }

  private Void verifyN(SampledComp c, Float? v, Status status := Status.ok)
  {
    if (v == null) { verifyNull(c.out); return }
    verifyEq(c.out.num.toFloat, v)
    verifyEq(c.out.status, status)
  }
}
