//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

class EdgeTest : HxCompTest
{

//////////////////////////////////////////////////////////////////////////
// BoolEdge
//////////////////////////////////////////////////////////////////////////

  ** Each edge type gives a pulse that clears at the next execute
  Void testEdges()
  {
    sim |cx|
    {
      r := mk(cx, "BoolEdge", ["in":sb(false)])
      f := mk(cx, "BoolEdge", ["in":sb(false), "edge":BoolEdgeType.falling])
      c := mk(cx, "BoolEdge", ["in":sb(false), "edge":BoolEdgeType.change])
      verifyEq(r->edge, BoolEdgeType.rising)
      [true, false].each |v|
      {
        [r, f, c].each |x| { x.set("in", sb(v)) }
        next(cx)
        verifyOut(r, v); verifyOut(f, !v); verifyOut(c, true)
        next(cx)
        [r, f, c].each |x| { verifyOut(x, false) }
      }
    }
  }

  ** initPrev is the previous in at the first execute only
  Void testInitPrev()
  {
    sim |cx|
    {
      e := mk(cx, "BoolEdge", ["in":sb(true), "initPrev":true])
      verifyOut(e, false)
      f := mk(cx, "BoolEdge", ["in":sb(false), "initPrev":true, "edge":BoolEdgeType.falling])
      verifyOut(f, true)
      step(cx, e, ["initPrev":false]); verifyOut(e, false)
    }
  }

  ** A null sets out to null, an invalid in is not compared
  Void testEdgeNullAndInvalid()
  {
    sim |cx|
    {
      e := mk(cx, "BoolEdge", Str:Obj?["in":null])
      verifyOut(e, null)
      step(cx, e, ["in":sb(false)]);               verifyOut(e, false)
      step(cx, e, Str:Obj?["in":null]);            verifyOut(e, null)
      step(cx, e, ["in":sb(true)]);                verifyOut(e, true)
      step(cx, e, ["in":sb(false, Status.fault)]); verifyOut(e, false, Status.fault)
      step(cx, e, ["in":sb(true)]);                verifyOut(e, false)
      step(cx, e, ["in":sb(false, Status.alarm)]); verifyOut(e, false, Status.alarm)
      step(cx, e, ["in":sb(true, Status.alarm)]);  verifyOut(e, true, Status.alarm)
      step(cx, e, Str:Obj?["in":null]);            verifyOut(e, null)
      step(cx, e, ["in":sb(true, Status.down)]);   verifyOut(e, null)
    }
  }

//////////////////////////////////////////////////////////////////////////
// NumberChange
//////////////////////////////////////////////////////////////////////////

  ** out, up and down pulse for one execute, and the unit is ignored
  Void testNumberChange()
  {
    sim |cx|
    {
      c := mk(cx, "NumberChange", ["in":sn(0)])
      verifyChg(c, false, false, false)
      step(cx, c, ["in":sn(2)]);              verifyChg(c, true, true, false)
      next(cx);                               verifyChg(c, false, false, false)
      step(cx, c, ["in":sn(0.5f)]);           verifyChg(c, true, false, true)
      step(cx, c, ["in":sn(n(0.5f, "°F"))]);  verifyChg(c, false, false, false)
      a := mk(cx, "NumberChange", ["in":sn(1), "initPrev":n(10)])
      verifyChg(a, true, false, true)
    }
  }

  ** A null gives null outputs, an invalid in is not compared, NaN is a fault
  Void testNumberChangeStatus()
  {
    sim |cx|
    {
      c := mk(cx, "NumberChange", Str:Obj?["in":null])
      verifyChg(c, null, null, null)
      step(cx, c, ["in":sn(0)]);               verifyChg(c, false, false, false)
      step(cx, c, ["in":sn(1, Status.fault)]); verifyChg(c, false, false, false, Status.fault)
      step(cx, c, ["in":sn(0)]);               verifyChg(c, false, false, false)
      step(cx, c, ["in":sn(Float.nan)]);       verifyChg(c, false, false, false, Status.fault)
      step(cx, c, ["in":sn(1, Status.alarm)]); verifyChg(c, true, true, false, Status.alarm)
      f := mk(cx, "NumberChange", ["in":sn(1, Status.stale), "initPrev":n(Float.nan)])
      verifyChg(f, false, false, false, Status.stale.merge(Status.fault))
    }
  }

  private Void sim(|SimulatedCompContext| f) { SimulatedCompContext(cs).asCur(f) }

  private Comp mk(SimulatedCompContext cx, Str spec, Str:Obj? slots)
  {
    c := createComp(spec)
    slots.each |v, n| { if (v != null) c.set(n, v) }
    cs.root.add(c)
    next(cx)
    return c
  }

  private Void next(SimulatedCompContext cx) { cx.step(cx.now + 1sec) }

  private Void step(SimulatedCompContext cx, Comp c, Str:Obj? slots)
  {
    slots.each |v, n| { c.set(n, v) }
    next(cx)
  }

  private Void verifyOut(Comp c, Bool? val, Status status := Status.ok) { verifyBool(c, "out", val, status) }

  private Void verifyChg(Comp c, Bool? out, Bool? up, Bool? down, Status status := Status.ok)
  {
    ["out":out, "up":up, "down":down].each |v, n| { verifyBool(c, n, v, status) }
  }

  private Void verifyBool(Comp c, Str slot, Bool? val, Status status)
  {
    if (val == null) verifyNull(c.get(slot), slot)
    else verifyEq(c.get(slot), sb(val, status), slot)
  }
}
