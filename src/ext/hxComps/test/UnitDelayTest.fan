//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using concurrent
using xeto
using xetom
using haystack

class UnitDelayTest : HxCompTest
{
  ** 2025-10-15T00:00:00Z, on the grid of any whole second period
  static const DateTime T := DateTime.fromJava(1_760_486_400_000, TimeZone.utc)

  ** out is yStart, then in as of the instant before.  A cut link captures
  ** in as it was on the instant's cycle, an uncut one a cycle later.
  Void testOpenChain()
  {
    r := createComp("Add")
    cut := newDelay
    uncut := newDelay
    SimulatedCompContext(cs, T).asCur |cx|
    {
      Comp[r, cut, uncut].each |x| { cs.root.add(x) }
      link(r, "out", cut, "in", true)
      link(r, "out", uncut, "in", false)
      r.set("inA", sn(1))
      cx.step(at(0))
      r.set("inA", sn(2))
      cx.step(at(1))
      verifyN(cut, 0f)
      verifyN(uncut, 0f)
      r.set("inA", sn(3))
      cx.step(at(10))
      verifyN(cut, 1f)
      verifyN(uncut, 2f)
      r.set("inA", sn(4))
      cx.step(at(11))
      cx.step(at(20))
      verifyN(cut, 3f)
      verifyN(uncut, 4f)
    }
  }

  ** y[k+1] = 3*y[k] + 1 through a cut delay, by two branches that may
  ** execute in either order, gives one trace in every creation order
  Void testLoopEveryOrder()
  {
    traces := Str[,]
    orders := Str[,]
    [[0, 1, 2, 3], [0, 1, 3, 2], [0, 2, 1, 3], [0, 2, 3, 1], [0, 3, 1, 2], [0, 3, 2, 1]].each |p|
    {
      Comp?[] c := [null, null, null, null]
      p.each |i| { c[i] = i == 0 ? newDelay(10sec, 1f) : createComp(i == 1 ? "Multiply" : "Add") }
      c[1].set("inB", sn(2))
      c[2].set("inB", sn(1))
      SimulatedCompContext(cs, T).asCur |cx|
      {
        p.each |i| { cs.root.add(c[i]) }
        link(c[0], "out", c[1], "inA", false)
        link(c[0], "out", c[2], "inA", false)
        link(c[1], "out", c[3], "inA", false)
        link(c[2], "out", c[3], "inB", false)
        link(c[3], "out", c[0], "in", true)
        trace := Str[,]
        (0..30).each |s|
        {
          cx.step(at(s))
          if (s % 10 == 0) trace.add(((StatusNumber)c[0].get("out")).num.toStr)
        }
        traces.add(trace.join(","))
        buf := StrBuf()
        cs.spi.dumpTopology(buf.out)
        lines := buf.toStr.splitLines
        orders.add(c.map |x| { lines.index(x.toStr) }.join(","))
        c.each |x| { cs.root.remove(x.name) }
      }
    }
    verify(orders.unique.size > 1, "creation orders gave one sort order: $orders")
    verifyEq(traces.unique, ["1,4,13,40"])
  }

  ** A null, invalid or NaN capture keeps the register and out stays ok.  A run of
  ** held captures logs a warning, and a line at its end.
  Void testNullInvalidNaN()
  {
    u := newDelay
    SimulatedCompContext(cs, T).asCur |cx|
    {
      cs.root.add(u)
      acc := Float[,]
      recs := capture |->|
      {
        [sn(4), null, sn(5, Status.down), sn(Number.nan), sn(6, Status.alarm), sn(7)].each |v, i|
        {
          u.set("in", v)
          cx.step(at(10 * i))
          acc.add(u.out.num.toFloat)
          verifyEq(u.out.status, Status.ok)
          cx.step(at(10 * i + 1))
        }
      }
      verifyEq(acc, [0f, 4f, 4f, 4f, 4f, 6f])
      tag := "UnitDelay @${u.id}.in: "
      verifyEq(recs.findAll |x| { x.msg.startsWith(tag) }.map |x->Str| { "$x.level " + x.msg[tag.size..-1] }, [
        "warn null captured, holding 4 (repeats not logged until it recovers)",
        "info hold recovered (repeats not logged: 2)"])
    }
  }

  ** A period below 1ms is a fault on the held value and loses the
  ** capture due; 1ms is not a fault
  Void testPeriodFault()
  {
    u := newDelay(0ms, 2f)
    SimulatedCompContext(cs, T).asCur |cx|
    {
      cs.root.add(u)
      u.set("in", sn(9))
      cx.step(at(0))
      verifyN(u, 2f, Status.fault)
      u.period = 10sec
      cx.step(at(10))
      cx.step(at(11))
      cx.step(at(20))
      verifyN(u, 9f)
      u.set("in", sn(3))
      u.period = 999_999ns
      cx.step(at(21))
      verifyN(u, 9f, Status.fault)
      u.period = 1ms
      cx.step(at(30))
      verifyN(u, 9f)
    }
  }

  ** Run f and return the records the hxComps log took meanwhile
  private LogRec[] capture(|->| f)
  {
    acc := LogRec[,]
    Actor.locals[key] = acc
    handler := |LogRec r| { if (r.logName == "hxComps") (Actor.locals[key] as LogRec[])?.add(r) }
    Log.addHandler(handler)
    try f()
    finally
    {
      Log.removeHandler(handler)
      Actor.locals.remove(key)
    }
    return acc
  }

  private static const Str key := "hxComps.unitDelayTest"

  private UnitDelay newDelay(Duration period := 10sec, Float yStart := 0f)
  {
    c := (UnitDelay)createComp("UnitDelay")
    c.period = period
    c.yStart = Number(yStart)
    return c
  }

  private static DateTime at(Int s) { T + Duration(s * 1sec.ticks) }

  private Void link(Comp from, Str fromSlot, Comp to, Str toSlot, Bool cut)
  {
    to.set("links", to.links.add(toSlot, CompUtil.toLink(from.id, fromSlot, cut)))
  }

  private Void verifyN(UnitDelay c, Float v, Status status := Status.ok)
  {
    verifyEq(c.out?.num?.toFloat, v)
    verifyEq(c.out.status, status)
  }
}
