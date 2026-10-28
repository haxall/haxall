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
  Void testNot()
  {
    TestHxCompContext().asCur |cx|
    {
      Not c := createAndExec("Not")
      verifyNull(c.out)

      setAndExec(c, "in", sb(true))
      verifyEq(c.out, sb(false))
      setAndExec(c, "in", sb(false))
      verifyEq(c.out, sb(true))

      // status passes through
      setAndExec(c, "in", sb(false, Status.alarm))
      verifyEq(c.out, sb(true, Status.alarm))

      // invalid input is false
      setAndExec(c, "in", sb(false, Status.down))
      verifyEq(c.out, sb(false, Status.down))

      setAndExec(c, "in", null)
      verifyNull(c.out)
    }
  }

  Void testAndOr()
  {
    TestHxCompContext().asCur |cx|
    {
      And and := createAndExec("And")
      Or or   := createAndExec("Or")
      verifyNull(and.out); verifyNull(or.out)

      // a single input is enough
      verifyQuad(and, [null, sb(true), null, null], sb(true))
      verifyQuad(or,  [null, sb(false), null, null], sb(false))

      // null inputs are ignored
      verifyQuad(and, [sb(true), null, sb(true), null], sb(true))
      verifyQuad(and, [sb(true), null, sb(false), null], sb(false))
      verifyQuad(or,  [sb(false), null, sb(false), null], sb(false))
      verifyQuad(or,  [sb(false), null, sb(true), null], sb(true))

      // all four
      verifyQuad(and, [sb(true), sb(true), sb(true), sb(true)], sb(true))
      verifyQuad(and, [sb(true), sb(true), sb(true), sb(false)], sb(false))
      verifyQuad(or,  [sb(false), sb(false), sb(false), sb(false)], sb(false))
      verifyQuad(or,  [sb(false), sb(false), sb(false), sb(true)], sb(true))

      // status is merged
      verifyQuad(and, [sb(true, Status.alarm), sb(true), null, sb(true, Status.overridden)],
        sb(true, Status.alarm.set(Status.overridden)))
      verifyQuad(or, [sb(false), sb(true, Status.alarm), null, null], sb(true, Status.alarm))

      // invalid inputs are not used, but their status is propagated
      verifyQuad(and, [sb(true), sb(false, Status.fault), null, null], sb(true, Status.fault))
      verifyQuad(or,  [sb(false), sb(true, Status.fault), null, null], sb(false, Status.fault))

      // no valid inputs is false, but non-null inputs count toward minInputs
      verifyQuad(and, [sb(true, Status.down), null, null, null], sb(false, Status.down))
      verifyQuad(or,  [sb(true, Status.down), null, null, null], sb(false, Status.down))

      // no inputs
      verifyQuad(and, [null, null, null, null], null)
      verifyQuad(or,  [null, null, null, null], null)
    }
  }

  Void testXor()
  {
    TestHxCompContext().asCur |cx|
    {
      Xor c := createAndExec("Xor")
      verifyNull(c.out)

      // needs at least two inputs
      verifyQuad(c, [sb(true), null, null, null], null)

      verifyQuad(c, [sb(true), sb(false), null, null], sb(true))
      verifyQuad(c, [sb(true), null, sb(true), null], sb(false))
      verifyQuad(c, [sb(false), null, null, sb(false)], sb(false))

      // true for an odd number of true inputs
      verifyQuad(c, [sb(true), sb(true), sb(true), null], sb(true))
      verifyQuad(c, [sb(true), sb(true), sb(true), sb(true)], sb(false))

      verifyQuad(c, [sb(true, Status.alarm), sb(false), null, null], sb(true, Status.alarm))

      // invalid inputs are not used, but count toward minInputs
      verifyQuad(c, [sb(true), sb(true, Status.stale), null, null], sb(true, Status.stale))
    }
  }

  Void testCompare()
  {
    TestHxCompContext().asCur |cx|
    {
      Comparison gt := createAndExec("GreaterThan")
      Comparison ge := createAndExec("GreaterThanEqual")
      Comparison lt := createAndExec("LessThan")
      Comparison le := createAndExec("LessThanEqual")
      Comparison eq := createAndExec("Equal")
      Comparison ne := createAndExec("NotEqual")
      all := [gt, ge, lt, le, eq, ne]
      all.each |c| { verifyNull(c.out) }

      // expected results are in the order: gt, ge, lt, le, eq, ne
      // a < b
      [false, false, true, true, false, true].each |v, i| { verifyCompare(all[i], n(1), n(2), sb(v)) }

      // a == b
      [false, true, false, true, true, false].each |v, i| { verifyCompare(all[i], n(2), n(2), sb(v)) }

      // a > b
      [true, true, false, false, false, true].each |v, i| { verifyCompare(all[i], n(3), n(2), sb(v)) }

      all.each |c|
      {
        // status is merged
        setAndExec(c, "inA", sn(2, Status.alarm))
        setAndExec(c, "inB", sn(2, Status.overridden))
        verifyEq(c.out.status, Status.alarm.set(Status.overridden))

        // invalid input is false
        setAndExec(c, "inA", sn(2, Status.down))
        setAndExec(c, "inB", sn(2))
        verifyEq(c.out, sb(false, Status.down))

        // null input is null
        setAndExec(c, "inA", null)
        verifyNull(c.out)
      }
    }
  }

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

  private Void verifyQuad(QuadLogic c, StatusBool?[] in, StatusBool? expected)
  {
    setAndExec(c, "inA", in[0])
    setAndExec(c, "inB", in[1])
    setAndExec(c, "inC", in[2])
    setAndExec(c, "inD", in[3])
    verifyEq(c.out, expected)
  }

  private Void verifyCompare(Comparison c, Number a, Number b, StatusBool expected)
  {
    setAndExec(c, "inA", sn(a))
    setAndExec(c, "inB", sn(b))
    verifyEq(c.out, expected)
  }
}
