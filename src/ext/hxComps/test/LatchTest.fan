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
    BoolLatch c := createComp("BoolLatch")
    cs.root.add(c)
    verifyNull(c.out)
    c.set("in", sb(false))
    verifyNull(c.out)
    c.clock = true
    verifyEq(c.out, sb(false))
    c.set("in", sb(true))
    verifyEq(c.out, sb(false))
    c.clock = false
    verifyEq(c.out, sb(false))
    c.clock = true
    verifyEq(c.out, sb(true))
    c.set("in", null)
    verifyEq(c.out, sb(true))
    c.clock = false
    verifyEq(c.out, sb(true))
    c.clock = true
    verifyNull(c.out)
  }
}