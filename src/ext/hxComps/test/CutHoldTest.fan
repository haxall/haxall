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

class CutHoldTest : HxCompTest
{
  ** 2025-10-15T00:00:00Z, on the grid of any whole second period
  static const DateTime T := DateTime.fromJava(1_760_486_400_000, TimeZone.utc)

  ** y[k+1] = 10 - y[k] through a cut hold starts from 0, one cycle late,
  ** in both creation orders
  Void testCutLoopStartsFromZero()
  {
    [[0, 1], [1, 0]].each |p|
    {
      SampledComp? z
      Comp? sub
      p.each |i|
      {
        if (i == 0) z = newHold("ZeroOrderHold")
        else sub = createComp("Subtract")
      }
      sub.set("inA", sn(10))
      SimulatedCompContext(cs, T).asCur |cx|
      {
        Comp?[z, sub].each |x| { cs.root.add(x) }
        link(z, "out", sub, "inB", false)
        link(sub, "out", z, "in", true)
        acc := Str[,]
        [0, 1, 9, 10, 20, 30].each |s|
        {
          cx.step(at(s))
          acc.add(show(z.out))
        }
        verifyEq(acc, ["0 ok", "10 ok", "10 ok", "0 ok", "10 ok", "0 ok"], "$p")
        Comp?[z, sub].each |x| { cs.root.remove(x.name) }
      }
    }
  }

  ** A cut ZeroOrderHold is 0 before its first sample, keeps its sample at
  ** an instant with a null, invalid or NaN in, and is ok, or fault for a
  ** bad period.  A run of held instants logs a warning, and a line at its end.
  Void testCutZohRegister()
  {
    r := createComp("NumberConst")
    z := newHold("ZeroOrderHold")
    SimulatedCompContext(cs, T).asCur |cx|
    {
      Comp[r, z].each |x| { cs.root.add(x) }
      link(r, "out", z, "in", true)
      acc := Str[,]
      recs := capture |->|
      {
        [null, sn(4), sn(5, Status.down), sn(Number.nan), sn(6, Status.alarm), null].each |v, i|
        {
          r.set("out", v)
          cx.step(at(10 * i - 1))
          cx.step(at(10 * i))
          acc.add(show(z.out))
        }
      }
      verifyEq(acc, ["0 ok", "4 ok", "4 ok", "4 ok", "6 ok", "6 ok"])
      tag := "ZeroOrderHold @${z.id}.in: "
      verifyEq(recs.findAll |x| { x.msg.startsWith(tag) }.map |x->Str| { "$x.level " + x.msg[tag.size..-1] }, [
        "warn null captured, holding 0 (repeats not logged until it recovers)",
        "info hold recovered (repeats not logged: 0)",
        "warn status down captured, holding 4 (repeats not logged until it recovers)",
        "info hold recovered (repeats not logged: 1)",
        "warn null captured, holding 6 (repeats not logged until it recovers)"])
      z.period = 0ms
      cx.step(at(51))
      verifyEq(show(z.out), "6 fault")
    }
  }

  ** The same for FirstOrderHold, which keeps following its line
  Void testCutFohRegister()
  {
    r := createComp("Add")
    f := newHold("FirstOrderHold")
    SimulatedCompContext(cs, T).asCur |cx|
    {
      Comp[r, f].each |x| { cs.root.add(x) }
      link(r, "out", f, "in", true)
      Int:Obj? steps := [0: sn(4), 5: sn(6), 13: null, 25: sn(8)]
      Int:Float exp := [0: 0f, 1: 4f, 10: 4f, 14: 4.8f, 15: 5f, 19: 5.8f, 20: 6f, 25: 6f, 30: 6f, 35: 7f]
      cx.step(T - 1sec)
      verifyEq(str(f.out), "0")
      (0..35).each |s|
      {
        if (steps.containsKey(s)) r.set("inA", steps[s])
        cx.step(at(s))
        e := exp[s]
        if (e != null)
        {
          verifyNotNull(f.out, "T+$s")
          verify((f.out.num.toFloat - e).abs < 1e-9f, "T+$s: $f.out, expected $e")
          verifyEq(f.out.status, Status.ok, "T+$s")
        }
      }
    }
  }

  ** Without a cut, with loopCut false, or on a Sampler, the null rule of
  ** SampledComp applies
  Void testNullRuleWithoutCut()
  {
    [["ZeroOrderHold", Str:Obj[:]],
     ["FirstOrderHold", Str:Obj["loopCut": false]],
     ["Sampler", Str:Obj["loopCut": Marker.val]]].each |c|
    {
      r := createComp("NumberConst")
      z := newHold(c[0])
      SimulatedCompContext(cs, T).asCur |cx|
      {
        Comp[r, z].each |x| { cs.root.add(x) }
        tags := ((Str:Obj)c[1]).dup.set("fromRef", r.id).set("fromSlot", "out")
        z.set("links", z.links.add("in", Etc.linkWrap(Etc.dictFromMap(tags))))
        r.set("out", sn(4))
        cx.step(at(0))
        cx.step(at(1))
        verifyEq(show(z.out), "4 ok", c[0])
        r.set("out", sn(4, Status.stale))
        cx.step(at(2))
        cx.step(at(3))
        verifyEq(show(z.out), "4 stale", c[0])
        r.set("out", null)
        cx.step(at(4))
        cx.step(at(5))
        verifyNull(z.out, c[0])
        Comp[r, z].each |x| { cs.root.remove(x.name) }
      }
    }
  }

  ** loopBreak is on the specs with no direct feedthrough, and only those
  Void testLoopBreakMeta()
  {
    ["UnitDelay", "ZeroOrderHold", "FirstOrderHold", "Sampler", "SampledComp", "Add"].each |n, i|
    {
      verifyEq(ns.spec("hx.comps::$n").meta.has("loopBreak"), i < 3, n)
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

  private static const Str key := "hxComps.cutHoldTest"

  private SampledComp newHold(Str type)
  {
    c := (SampledComp)createComp(type)
    c.period = 10sec
    return c
  }

  private static DateTime at(Int s) { T + Duration(s * 1sec.ticks) }

  private Void link(Comp from, Str fromSlot, Comp to, Str toSlot, Bool cut)
  {
    to.set("links", to.links.add(toSlot, CompUtil.toLink(from.id, fromSlot, cut)))
  }

  private static Str str(StatusNumber? v) { v == null ? "null" : v.num.toStr }

  private static Str show(StatusNumber? v) { v == null ? "null" : "$v.num $v.status" }
}
