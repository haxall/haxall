//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   07 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

class SwitchTest : HxCompTest
{
  ** NOTE: all behavior of the various selects is implemented in the Select
  ** base class - so we just use number select to test the various states
  ** which should prove all the other cases
  Void testSwitch()
  {
    TestHxCompContext().asCur |cx|
    {
      NumberSwitch c := createAndExec("NumberSwitch")
      verifyNull(c.out)

      // configure inputs without setting the switch should still yield null
      setAndExec(c, "inTrue", sn(100))
      setAndExec(c, "inFalse", sn(200))
      verifyNull(c.out)

      setAndExec(c, "inSwitch", sb(true))
      verifyEq(c.out, sn(100))

      setAndExec(c, "inTrue", sn(-100))
      verifyEq(c.out, sn(-100))

      setAndExec(c, "inSwitch", sb(false))
      verifyEq(c.out, sn(200))

      setAndExec(c, "inFalse", sn(-200))
      verifyEq(c.out, sn(-200))
    }
  }
}