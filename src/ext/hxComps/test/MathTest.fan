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

  Void testUnary()
  {
    TestHxCompContext().asCur |cx|
    {
      pi := Float.pi
      verifyUnary("AbsValue",    -3f,    3f)
      verifyUnary("AbsValue",    3f,     3f)
      verifyUnary("Exponential", 1f,     Float.e)
      verifyUnary("LogBase10",   100f,   2f)
      verifyUnary("LogNatural",  Float.e, 1f)
      verifyUnary("Negative",    3f,     -3f)
      verifyUnary("SquareRoot",  9f,     3f)
      verifyUnary("Sine",        pi/2f,  1f)
      verifyUnary("Cosine",      0f,     1f)
      verifyUnary("Tangent",     pi/4f,  1f)
      verifyUnary("ArcSine",     1f,     pi/2f)
      verifyUnary("ArcCosine",   1f,     0f)
      verifyUnary("ArcTangent",  1f,     pi/4f)

      // units are kept where the result has the same dimension
      AbsValue abs := createAndExec("AbsValue")
      setAndExec(abs, "inA", sn(n(-3, "ft")))
      verifyEq(abs.out, sn(n(3, "ft")))
      Negative neg := createAndExec("Negative")
      setAndExec(neg, "inA", sn(n(3, "ft")))
      verifyEq(neg.out, sn(n(-3, "ft")))
    }
  }

  private Void verifyUnary(Str spec, Float in, Float expected)
  {
    UnaryMath c := createAndExec(spec)
    verifyNull(c.out)

    setAndExec(c, "inA", sn(in))
    verifyStatus(sn(expected), c.out)

    // status passes through
    setAndExec(c, "inA", sn(in, Status.alarm))
    verifyStatus(sn(expected, Status.alarm), c.out)

    setAndExec(c, "inA", null)
    verifyNull(c.out)
  }

  Void testBinary()
  {
    TestHxCompContext().asCur |cx|
    {
      Subtract sub := createAndExec("Subtract")
      Divide div   := createAndExec("Divide")
      Modulus mod  := createAndExec("Modulus")
      Power pow    := createAndExec("Power")
      all := BinaryMath[sub, div, mod, pow]
      all.each |c| { verifyNull(c.out) }

      verifyAB(sub, n(5), n(2), sn(3))
      verifyAB(sub, n(2), n(5), sn(-3))
      verifyAB(div, n(6), n(4), sn(1.5f))
      verifyAB(mod, n(7), n(3), sn(1))
      verifyAB(mod, n(-7), n(3), sn(-1))
      verifyAB(pow, n(2), n(10), sn(1024))
      verifyAB(pow, n(4), n(0.5f), sn(2))

      all.each |c|
      {
        // status is merged
        setAndExec(c, "inA", sn(6, Status.alarm))
        setAndExec(c, "inB", sn(2, Status.overridden))
        verifyEq(c.out.status, Status.alarm.set(Status.overridden))

        // invalid input is NaN without adding fault
        setAndExec(c, "inA", sn(6, Status.down))
        setAndExec(c, "inB", sn(2))
        verifyEq(c.out, sn(Number.nan, Status.down))

        // null input is null
        setAndExec(c, "inB", null)
        verifyNull(c.out)
      }
    }
  }

  Void testQuad()
  {
    TestHxCompContext().asCur |cx|
    {
      Add add      := createAndExec("Add")
      Multiply mul := createAndExec("Multiply")
      Average avg  := createAndExec("Average")
      all := QuadMath[add, mul, avg]
      all.each |c| { verifyNull(c.out) }

      // a single input is enough
      verifyQuad(add, [null, null, sn(3), null], sn(3))
      verifyQuad(mul, [null, null, sn(3), null], sn(3))
      verifyQuad(avg, [null, null, sn(3), null], sn(3))

      // null inputs are ignored
      verifyQuad(add, [sn(2), null, sn(3), null], sn(5))
      verifyQuad(mul, [sn(2), null, sn(3), null], sn(6))
      verifyQuad(avg, [sn(2), null, sn(3), null], sn(2.5f))

      // all four
      verifyQuad(add, [sn(1), sn(2), sn(3), sn(4)], sn(10))
      verifyQuad(mul, [sn(1), sn(2), sn(3), sn(4)], sn(24))
      verifyQuad(avg, [sn(1), sn(2), sn(3), sn(4)], sn(2.5f))

      all.each |c|
      {
        // status is merged
        setQuad(c, [sn(2, Status.alarm), null, null, sn(2, Status.overridden)])
        verifyEq(c.out.status, Status.alarm.set(Status.overridden))

        // no inputs
        verifyQuad(c, [null, null, null, null], null)
      }
    }
  }

  private Void verifyQuad(QuadMath c, StatusNumber?[] in, StatusNumber? expected)
  {
    setQuad(c, in)
    if (expected == null) verifyNull(c.out)
    else verifyStatus(expected, c.out)
  }

  private Void setQuad(QuadMath c, StatusNumber?[] in)
  {
    setAndExec(c, "inA", in[0])
    setAndExec(c, "inB", in[1])
    setAndExec(c, "inC", in[2])
    setAndExec(c, "inD", in[3])
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

  Void testNaNFault()
  {
    TestHxCompContext().asCur |cx|
    {
      LogNatural ln := createAndExec("LogNatural")
      setAndExec(ln, "inA", sn(-2.5f))
      verifyEq(ln.out, sn(Number.nan, Status.fault))
      setAndExec(ln, "inA", sn(1))
      verifyEq(ln.out, sn(0))

      SquareRoot sqrt := createAndExec("SquareRoot")
      setAndExec(sqrt, "inA", sn(-1))
      verifyEq(sqrt.out, sn(Number.nan, Status.fault))

      // NaN input
      setAndExec(sqrt, "inA", sn(Number.nan))
      verifyEq(sqrt.out, sn(Number.nan, Status.fault))

      // factorial of a negative or NaN is undefined; non-integers truncate
      Factorial f := createAndExec("Factorial")
      setAndExec(f, "inA", sn(-3))
      verifyEq(f.out, sn(Number.nan, Status.fault))
      setAndExec(f, "inA", sn(Number.nan))
      verifyEq(f.out, sn(Number.nan, Status.fault))
      setAndExec(f, "inA", sn(0))
      verifyEq(f.out, sn(1))
      setAndExec(f, "inA", sn(5.7f))
      verifyEq(f.out, sn(120))

      // 0/0 is NaN, but 1/0 is a valid +INF
      Divide div := createAndExec("Divide")
      verifyAB(div, n(0), n(0), sn(Number.nan, Status.fault))
      verifyAB(div, n(1), n(0), sn(Number.posInf))

      Power pow := createAndExec("Power")
      verifyAB(pow, n(-8), n(0.5f), sn(Number.nan, Status.fault))
      verifyAB(pow, n(2), n(3), sn(8))
    }
  }

  private Void verifyAB(Comp c, Number a, Number b, StatusNumber expected)
  {
    setAndExec(c, "inA", sn(a))
    setAndExec(c, "inB", sn(b))
    verifyEq(c->out, expected)
  }
}
