//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

class TriggeredTest : HxCompTest
{
  static const DateTime T := DateTime.fromJava(1_760_486_400_000, TimeZone.utc)

  ** out is yStart until a rise, a true trigger at init is not a rise, and
  ** a sample keeps the status in had
  Void testSampler()
  {
    sim("TriggeredSampler") |c, cx|
    {
      c.set("yStart", Number(1))
      step(cx, c, 5, true);                    verifyN(c, 1f)
      step(cx, c, 6, false);                   verifyN(c, 1f)
      step(cx, c, sn(7, Status.alarm), true);  verifyN(c, 7f, Status.alarm)
      step(cx, c, 8, true);                    verifyN(c, 7f, Status.alarm)
      step(cx, c, 9, false);                   verifyN(c, 7f, Status.alarm)
      step(cx, c, 10, true);                   verifyN(c, 10f)
    }
  }

  ** The rise is read on execute, so the sample is in on that cycle, here
  ** pushed after the rise
  Void testSamplesTheCycleOfTheRise()
  {
    src := createComp("Not")
    sw := createComp("NumberSwitch")
    c := createComp("TriggeredSampler")
    sw.set("inTrue", sn(10))
    sw.set("inFalse", sn(20))
    SimulatedCompContext(cs, T).asCur |cx|
    {
      cs.root.add(src)
      cs.root.add(sw)
      cs.root.add(c)
      sw.set("links", sw.links.add("inSwitch", Etc.link(src.id, "out")))
      c.set("links", c.links.add("in", Etc.link(sw.id, "out")).add("trigger", Etc.link(src.id, "out")))
      src.set("in", sb(true))
      cx.step(T);         verifyN(c, 0f)
      src.set("in", sb(false))
      cx.step(T+1sec);    verifyN(c, 10f)
      src.set("in", sb(true))
      cx.step(T+2sec);    verifyN(c, 10f)
      verifyEq(sw.get("out"), sn(20))
      cs.root.remove(c.name)
      cs.root.remove(sw.name)
      cs.root.remove(src.name)
    }
  }

  ** A SampleTrigger with a one-cycle period stays true, which is one
  ** rise, so out stays yStart
  Void testOneCyclePeriodNeverRises()
  {
    trig := createComp("SampleTrigger")
    trig.set("period", 1sec)
    c := createComp("TriggeredSampler")
    SimulatedCompContext(cs, T).asCur |cx|
    {
      cs.root.add(trig)
      cs.root.add(c)
      c.set("links", c.links.add("trigger", Etc.link(trig.id, "out")))
      6.times |i|
      {
        c.set("in", sn(10 + i))
        cx.step(T + Duration(i * 1sec.ticks))
        verifyEq(trig.get("out"), sb(true))
        verifyN(c, 0f)
      }
    }
  }

  ** Init sets out to in, not its absolute value, and each rise takes the
  ** larger of out and the absolute value of in
  Void testMax()
  {
    sim("TriggeredMax") |c, cx|
    {
      step(cx, c, -3, true);   verifyN(c, -3f)
      step(cx, c, -5, false);  verifyN(c, -3f)
      step(cx, c, -1, true);   verifyN(c, 1f)
      step(cx, c, 9, false);   verifyN(c, 1f)
      step(cx, c, -4, true);   verifyN(c, 4f)
      step(cx, c, 9, false)
      step(cx, c, 2, true);    verifyN(c, 4f)
    }
  }

  ** The mean of the last n samples, the first at init.  An n below 1
  ** faults, and a new n, even on a rise, starts again with one sample.
  Void testMovingMean()
  {
    sim("TriggeredMovingMean") |c, cx|
    {
      c.set("n", 2)
      step(cx, c, 2, false);   verifyN(c, 2f)
      step(cx, c, 4, true);    verifyN(c, 3f)
      step(cx, c, 4, false)
      step(cx, c, 10, true);   verifyN(c, 7f)
      c.set("n", 0)
      step(cx, c, 1, false);   verifyN(c, 7f, Status.fault)
      c.set("n", 2)
      step(cx, c, 6, false);   verifyN(c, 6f)
      c.set("n", 3)
      step(cx, c, 12, true);   verifyN(c, 12f)
      step(cx, c, 12, false)
      step(cx, c, 3, true);    verifyN(c, 7.5f)
    }
  }

  ** A null input gives null, an invalid one holds out with the merged
  ** status, and a NaN in holds it with fault.  A rise meanwhile takes no
  ** sample, and is judged against the last valid trigger.
  Void testNullInvalidNaN()
  {
    ["TriggeredSampler", "TriggeredMax", "TriggeredMovingMean"].each |type|
    {
      v := type == "TriggeredSampler" ? 0f : 5f
      sim(type) |c, cx|
      {
        step(cx, c, 5, false);                    verifyN(c, v)
        step(cx, c, null, true);                  verifyN(c, null)
        step(cx, c, 9, false);                    verifyN(c, v)
        step(cx, c, sn(7, Status.down), true);    verifyN(c, v, Status.down)
        step(cx, c, 7, true);                     verifyN(c, v)
        step(cx, c, 7, false)
        step(cx, c, Float.nan, true);             verifyN(c, v, Status.fault)
        step(cx, c, 8, true);                     verifyN(c, v)
        step(cx, c, 8, false)
        step(cx, c, 8, sb(true, Status.stale));   verifyN(c, v, Status.stale)
        step(cx, c, 8, true);                     verifyN(c, 8f)
      }
    }
  }

  ** Mount a comp of type and run f at T
  private Void sim(Str type, |Comp, SimulatedCompContext| f)
  {
    c := createComp(type)
    SimulatedCompContext(cs, T).asCur |cx| { cs.root.add(c); f(c, cx); cs.root.remove(c.name) }
  }

  ** Set in and trigger, each a value, a status value or null, and step 1 sec
  private Void step(SimulatedCompContext cx, Comp c, Obj? u, Obj? t)
  {
    c.set("in", u == null || u is StatusNumber ? u : sn(u))
    c.set("trigger", t == null || t is StatusBool ? t : sb(t))
    cx.step(cx.now + 1sec)
  }

  private Void verifyN(Comp c, Float? v, Status status := Status.ok, Str msg := "")
  {
    out := c.get("out") as StatusNumber
    if (v == null) { verifyNull(out, msg); return }
    verifyNotNull(out, msg)
    verifyEq(out.num.toFloat, v, msg)
    verifyEq(out.status, status, msg)
  }
}
