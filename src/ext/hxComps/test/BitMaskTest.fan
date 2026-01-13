//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

class BitMaskTest : HxCompTest
{
  Void testBitAnd()
  {
    TestHxCompContext().asCur() |cx|
    {
      BitAnd c := createAndExec("BitAnd")
      verifyNull(c.out)

      setAndExec(c, "in", sn(0b1111))
      verifyNull(c.out)

      c.mask = sn(0b1001); cs.execute
      verifyEq(c.out, sn(0b1001))

      c.mask = sn(0b0110); cs.execute
      verifyEq(c.out, sn(0b0110))
    }
  }

  Void testBitOr()
  {
    TestHxCompContext().asCur |cx|
    {
      BitOr c := createAndExec("BitOr")
      verifyNull(c.out)

      setAndExec(c, "in", sn(0b0101))
      verifyNull(c.out)

      c.mask = sn(0b1001); cs.execute
      verifyEq(c.out, sn(0b1101))

      c.mask = sn(0b0010); cs.execute
      verifyEq(c.out, sn(0b0111))
    }
  }

  Void testBitXor()
  {
    TestHxCompContext().asCur |cx|
    {
      BitXor c := createAndExec("BitXor")
      verifyNull(c.out)

      setAndExec(c, "in", sn(0b0101))
      verifyNull(c.out)

      c.mask = sn(0b1001); cs.execute
      verifyEq(c.out, sn(0b1100))

      c.mask = sn(0b0010); cs.execute
      verifyEq(c.out, sn(0b0111))
    }
  }
}
