//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   07 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

class SelectTest : HxCompTest
{
  ** NOTE: all behavior of the various selects is implemented in the Select
  ** base class - so we just use number select to test the various states
  ** which should prove all the other cases
  Void testSelect()
  {
    TestHxCompContext().asCur |cx|
    {
      NumberSelect c := createAndExec("NumberSelect")
      initInputs(c)

      verifyNull(c.select)
      verifyNull(c.out)
      verifyFalse(c.zeroBasedSelect)
      verifyEq(c.numInputs, 3)

      // verify select == min (1)
      c.select = sn(1); cs.execute
      verifyEq(c.out, c.inA)
      // verify select < 1
      c.select = sn(0); cs.execute
      verifyEq(c.out, c.inA)
      // verify select == max
      c.select = sn(3); cs.execute
      verifyEq(c.out, c.inC)
      // verify select > max (3)
      c.select = sn(4); cs.execute
      verifyEq(c.out, c.inC)

      // set select > max to last slot (10)
      c.select = sn(10); cs.execute
      verifyEq(c.out, c.inC)
      // now change numInputs to 10 - it should update
      c.numInputs = 10; cs.execute
      verifyEq(c.out, c.inJ)

      // modify the input and verify the out changes
      setAndExec(c, "inJ", sn(100))
      verifyEq(c.out, sn(100))

      // switch to zero based select
      c.zeroBasedSelect = true; cs.execute
      verifyEq(c.out, sn(100))
      c.select = sn(0); cs.execute
      verifyEq(c.out, c.inA)
      c.select = sn(8); cs.execute
      verifyEq(c.out, c.inI)
    }
  }

  private Void initInputs(NumberSelect c)
  {
    10.times |x|
    {
      slot := "in" + ('A'+x).toChar
      c.set(slot, sn(x+1))
    }
  }
}
