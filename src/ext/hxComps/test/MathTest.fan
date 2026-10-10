//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Oct 2026  Matthew Giannini  Creation
//

using xeto
using haystack

class MathTest : HxCompTest
{
  Void testMinMax()
  {
    TestHxCompContext().asCur |cx|
    {
      Minimum min := createAndExec("Minimum")
      Maximum max := createAndExec("Maximum")
      verifyNull(min.out); verifyNull(max.out)

      // inA is empty
      [min, max].each |Comp c|
      {
        setAndExec(c, "inB", sn(2))
        setAndExec(c, "inD", sn(4))
      }
      verifyEq(min.out, sn(2))
      verifyEq(max.out, sn(4))

      setAndExec(min, "inA", sn(1))
      setAndExec(max, "inA", sn(5))
      verifyEq(min.out, sn(1))
      verifyEq(max.out, sn(5))

      // only inC
      [min, max].each |Comp c|
      {
        setAndExec(c, "inA", null)
        setAndExec(c, "inB", null)
        setAndExec(c, "inD", null)
        setAndExec(c, "inC", sn(3))
      }
      verifyEq(min.out, sn(3))
      verifyEq(max.out, sn(3))
    }
  }

  Void testFactorial()
  {
    TestHxCompContext().asCur |cx|
    {
      Factorial c := createAndExec("Factorial")
      verifyNull(c.out)

      setAndExec(c, "inA", sn(5))
      verifyEq(c.out, sn(120))

      setAndExec(c, "inA", sn(1000))
      verifyEq(c.out, StatusNumber(Number.posInf, Status.fault))

      setAndExec(c, "inA", null)
      verifyNull(c.out)

      // execute swallows errs, so call directly
      c.onExecute
      verifyNull(c.out)
    }
  }
}
