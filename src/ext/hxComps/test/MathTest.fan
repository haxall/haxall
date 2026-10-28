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

  Void testQuadUnits()
  {
    TestHxCompContext().asCur |cx|
    {
      ft := Unit("ft")
      m  := Unit("m")

      Add add      := createAndExec("Add")
      Multiply mul := createAndExec("Multiply")
      Average avg  := createAndExec("Average")
      Maximum max  := createAndExec("Maximum")

      // units are kept and unitless matches any unit like Axon
      verifyAB(add, n(1, ft), n(2, ft), sn(n(3, ft)))
      verifyAB(add, n(1, ft), n(2), sn(n(3, ft)))
      verifyAB(mul, n(2, ft), n(3), sn(n(6, ft)))
      verifyAB(mul, n(2, ft), n(3, ft), sn(n(6, ft * ft)))
      verifyAB(avg, n(7, ft), n(3), sn(n(5, ft)))

      // unlike units put out in fault
      verifyAB(add, n(1, ft), n(2, m), sn(Number.nan, Status.fault))
      verifyAB(avg, n(1, ft), n(2, m), sn(Number.nan, Status.fault))

      // fault clears when units are compatible again
      verifyAB(add, n(1, m), n(2, m), sn(n(3, m)))

      // like Axon max() units are not checked
      verifyAB(max, n(7.2f, ft), n(100, m), sn(n(100, m)))
    }
  }

  Void testBinaryUnits()
  {
    TestHxCompContext().asCur |cx|
    {
      ft := Unit("ft")
      m  := Unit("m")

      Subtract sub := createAndExec("Subtract")
      Modulus mod  := createAndExec("Modulus")

      verifyAB(sub, n(5, ft), n(2), sn(n(3, ft)))
      verifyAB(sub, n(5, ft), n(2, m), sn(Number.nan, Status.fault))
      verifyAB(mod, n(5, ft), n(2, ft), sn(Number.nan, Status.fault))
      verifyAB(mod, n(5, ft), n(2), sn(n(1, ft)))
    }
  }

  private Void verifyAB(Comp c, Number a, Number b, StatusNumber expected)
  {
    setAndExec(c, "inA", sn(a))
    setAndExec(c, "inB", sn(b))
    verifyEq(c->out, expected)
  }
}
