//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   06 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

class LatchTest : HxCompTest
{
  ** NOTE: all behavior of the various latches is implemented in the Latch
  ** base class - so we just use bool latch to test the transition states which
  ** should prove all the other cases.
  Void testLatch()
  {
    TestHxCompContext().asCur |cx|
    {
      BoolLatch c := createComp("BoolLatch")
      cs.root.add(c)
      verifyNull(c.out)
      setAndExec(c, "in", sb(false))
      verifyNull(c.out)
      setAndExec(c, "clock", sb(true))
      verifyEq(c.out, sb(false))
      setAndExec(c, "in", sb(true))
      verifyEq(c.out, sb(false))
      setAndExec(c, "clock", sb(false))
      verifyEq(c.out, sb(false))
      setAndExec(c, "clock", sb(true))
      verifyEq(c.out, sb(true))
      setAndExec(c, "in", null)
      verifyEq(c.out, sb(true))
      setAndExec(c, "clock", sb(false))
      verifyEq(c.out, sb(true))
      setAndExec(c, "clock", sb(true))
      verifyNull(c.out)
    }
  }

  ** in changes on the cycle the clock rises: the latch takes the new in
  Void testLatchReadsInOnExecute()
  {
    TestHxCompContext().asCur |cx|
    {
      src := createComp("Not")
      inv := createComp("Not")
      BoolLatch c := createComp("BoolLatch")
      cs.root.add(src)
      cs.root.add(inv)
      cs.root.add(c)
      inv.set("links", inv.links.add("in", Etc.link(src.id, "out")))
      c.set("links", c.links.add("clock", Etc.link(src.id, "out")).add("in", Etc.link(inv.id, "out")))
      setAndExec(src, "in", sb(true))
      verifyEq(c.in, sb(true))
      verifyNull(c.out)
      setAndExec(src, "in", sb(false))
      verifyEq(c.out, sb(false))
      setAndExec(src, "in", sb(true))
      verifyEq(c.out, sb(false))
      setAndExec(src, "in", sb(false))
      verifyEq(c.out, sb(false))
    }
  }

  ** A null or invalid clock holds out, and a rise is judged against the
  ** last valid clock
  Void testNullAndInvalidClock()
  {
    TestHxCompContext().asCur |cx|
    {
      NumberLatch c := createComp("NumberLatch")
      cs.root.add(c)
      setAndExec(c, "in", sn(1))
      setAndExec(c, "clock", sb(true))
      verifyEq(c.out, sn(1))
      setAndExec(c, "in", sn(2))
      setAndExec(c, "clock", null)
      setAndExec(c, "clock", sb(true))
      verifyEq(c.out, sn(1))
      setAndExec(c, "clock", sb(false, Status.fault))
      setAndExec(c, "clock", sb(true))
      verifyEq(c.out, sn(1))
      setAndExec(c, "clock", sb(false))
      setAndExec(c, "clock", sb(true, Status.down))
      verifyEq(c.out, sn(1))
      setAndExec(c, "clock", sb(true))
      verifyEq(c.out, sn(2))
    }
  }
}
