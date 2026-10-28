//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Oct 2026  Matthew Giannini  Creation
//

using xeto
using haystack

class LogicTest : HxCompTest
{
  Void testCompareUnits()
  {
    TestHxCompContext().asCur |cx|
    {
      ft  := Unit("ft")
      m   := Unit("m")
      min := Unit("min")
      sec := Unit("s")

      Comparison eq := createAndExec("Equal")
      Comparison ne := createAndExec("NotEqual")
      Comparison gt := createAndExec("GreaterThan")

      // unitless matches any unit like Axon
      verifyCompare(eq, n(7.2f, ft), n(7.2f), sb(true))
      verifyCompare(eq, n(7.2f), n(7.2f, ft), sb(true))
      verifyCompare(ne, n(7.2f, ft), n(7.2f), sb(false))
      verifyCompare(gt, n(8, ft), n(7), sb(true))

      // like units
      verifyCompare(eq, n(7.2f, ft), n(7.2f, ft), sb(true))
      verifyCompare(ne, n(7.2f, ft), n(7.3f, ft), sb(true))

      // unlike units are not equal
      verifyCompare(eq, n(7.2f, ft), n(7.2f, m), sb(false))
      verifyCompare(ne, n(7.2f, ft), n(7.2f, m), sb(true))

      // time units compare across units
      verifyCompare(gt, n(1, min), n(30, sec), sb(true))

      // unlike units can't be ordered
      verifyCompare(gt, n(1, ft), n(2, m), sb(false, Status.fault))

      // fault clears when units are compatible again
      verifyCompare(gt, n(3, ft), n(2, ft), sb(true))
    }
  }

  private Void verifyCompare(Comparison c, Number a, Number b, StatusBool expected)
  {
    setAndExec(c, "inA", sn(a))
    setAndExec(c, "inB", sn(b))
    verifyEq(c.out, expected)
  }
}
