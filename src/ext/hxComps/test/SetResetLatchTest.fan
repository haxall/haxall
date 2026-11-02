//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

class SetResetLatchTest : HxCompTest
{

//////////////////////////////////////////////////////////////////////////
// SetResetLatch
//////////////////////////////////////////////////////////////////////////

  ** A rise of in sets out, a rise of inClear clears it and wins
  Void testLatch()
  {
    sim |cx|
    {
      l := mk(cx, "SetResetLatch", ["in":sb(true), "inClear":sb(false)])
      verifyOut(l, true)
      step(cx, l, ["in":sb(false)]);                    verifyOut(l, true)
      step(cx, l, ["in":sb(true), "inClear":sb(true)]); verifyOut(l, false)
      step(cx, l, ["in":sb(false)]);                    verifyOut(l, false)
      step(cx, l, ["in":sb(true)]);                     verifyOut(l, false)
      step(cx, l, ["inClear":sb(false)]);               verifyOut(l, false)
      step(cx, l, ["in":sb(false)]);                    verifyOut(l, false)
      step(cx, l, ["in":sb(true)]);                     verifyOut(l, true)
    }
  }

  ** A null in writes null, an invalid one holds out, and inClear still clears
  Void testLatchNullAndInvalid()
  {
    sim |cx|
    {
      l := mk(cx, "SetResetLatch", Str:Obj?["in":null, "inClear":sb(false)])
      verifyOut(l, null)
      step(cx, l, ["in":sb(true)]);                     verifyOut(l, true)
      step(cx, l, Str:Obj?["in":null]);                 verifyOut(l, null)
      step(cx, l, ["inClear":sb(true)]);                verifyOut(l, null)
      step(cx, l, ["inClear":sb(false)]);               verifyOut(l, null)
      step(cx, l, ["in":sb(true)]);                     verifyOut(l, false)
      step(cx, l, ["in":sb(false)]);                    verifyOut(l, false)
      step(cx, l, ["in":sb(true)]);                     verifyOut(l, true)
      step(cx, l, ["inClear":sb(true, Status.fault)]);  verifyOut(l, true, Status.fault)
      step(cx, l, ["inClear":sb(true)]);                verifyOut(l, false)
      step(cx, l, ["in":sb(false), "inClear":sb(false)]); verifyOut(l, false)
      step(cx, l, ["in":sb(true)]);                     verifyOut(l, true)
      step(cx, l, ["in":sb(false, Status.fault)]);      verifyOut(l, true, Status.fault)
      step(cx, l, ["inClear":sb(true)]);                verifyOut(l, false, Status.fault)
      step(cx, l, ["in":sb(true, Status.alarm)]);       verifyOut(l, false, Status.alarm)
      step(cx, l, Str:Obj?["in":null]);                 verifyOut(l, null)
      step(cx, l, ["in":sb(true, Status.down)]);        verifyOut(l, null)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Toggle
//////////////////////////////////////////////////////////////////////////

  ** Each rise of in flips out, a rise of inClear clears it and wins
  Void testToggle()
  {
    sim |cx|
    {
      t := mk(cx, "Toggle", ["in":sb(false), "inClear":sb(false)])
      verifyOut(t, false)
      step(cx, t, ["in":sb(true)]);                     verifyOut(t, true)
      step(cx, t, ["in":sb(false)]);                    verifyOut(t, true)
      step(cx, t, ["in":sb(true)]);                     verifyOut(t, false)
      step(cx, t, ["in":sb(false)]);                    verifyOut(t, false)
      step(cx, t, ["in":sb(true)]);                     verifyOut(t, true)
      step(cx, t, ["in":sb(false)]);                    verifyOut(t, true)
      step(cx, t, ["in":sb(true), "inClear":sb(true)]); verifyOut(t, false)
      step(cx, t, ["in":sb(false)]);                    verifyOut(t, false)
      step(cx, t, ["in":sb(true)]);                     verifyOut(t, false)
      step(cx, t, ["inClear":sb(false)]);               verifyOut(t, false)
    }
  }

  ** A null in writes null, an invalid one holds out, and inClear still clears
  Void testToggleNullAndInvalid()
  {
    sim |cx|
    {
      t := mk(cx, "Toggle", Str:Obj?["in":null, "inClear":sb(false)])
      verifyOut(t, null)
      step(cx, t, ["in":sb(true)]);                verifyOut(t, true)
      step(cx, t, Str:Obj?["in":null]);            verifyOut(t, null)
      step(cx, t, ["in":sb(true)]);                verifyOut(t, true)
      step(cx, t, Str:Obj?["in":null]);            verifyOut(t, null)
      step(cx, t, ["inClear":sb(true)]);           verifyOut(t, null)
      step(cx, t, ["inClear":sb(false)]);          verifyOut(t, null)
      step(cx, t, ["in":sb(true)]);                verifyOut(t, false)
      step(cx, t, ["in":sb(false)]);               verifyOut(t, false)
      step(cx, t, ["in":sb(true)]);                verifyOut(t, true)
      step(cx, t, ["in":sb(false, Status.fault)]); verifyOut(t, true, Status.fault)
      step(cx, t, ["in":sb(true)]);                verifyOut(t, true)
      step(cx, t, ["in":sb(false)]);               verifyOut(t, true)
      step(cx, t, ["in":sb(true, Status.fault)]);  verifyOut(t, true, Status.fault)
      step(cx, t, ["inClear":sb(true)]);           verifyOut(t, false, Status.fault)
      step(cx, t, Str:Obj?["in":null]);            verifyOut(t, null)
      step(cx, t, ["in":sb(false, Status.down)]);  verifyOut(t, null)
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

  private Void verifyOut(Comp c, Bool? val, Status status := Status.ok)
  {
    if (val == null) verifyNull(c.get("out"))
    else verifyEq(c.get("out"), sb(val, status))
  }
}
