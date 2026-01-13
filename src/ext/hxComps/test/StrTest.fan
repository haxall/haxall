//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   07 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

class StringTest : HxCompTest
{
  Void testStrConcat()
  {
    TestHxCompContext().asCur |cx|
    {
      StrConcat c := createAndExec("StrConcat")
      verifyEq(c.out, ss(""))
      setAndExec(c, "inA", ss("foo"))
      verifyEq(c.out, ss("foo"))
      setAndExec(c, "inB", ss("bar"))
      verifyEq(c.out, ss("foobar"))
      setAndExec(c, "inC", ss("baz"))
      verifyEq(c.out, ss("foobarbaz"))
      setAndExec(c, "inD", ss("qat"))
      verifyEq(c.out, ss("foobarbazqat"))

      // verify some null and some not
      setAndExec(c, "inA", null)
      verifyEq(c.out, ss("barbazqat"))
      setAndExec(c, "inC", null)
      verifyEq(c.out, ss("barqat"))
    }
  }

  Void testStrContains()
  {
    TestHxCompContext().asCur |cx|
    {
      StrContains c := createAndExec("StrContains")
      verifyFalse(c.out.val)

      setAndExec(c, "inA", ss("foobarbaz"))
      verifyFalse(c.out.val)
      setAndExec(c, "inB", ss("foo"))
      verify(c.out.val)
      verifyEq(c.startIndex, 0)
      verifyEq(c.afterIndex, 3)

      setAndExec(c, "inB", ss("bar"))
      verify(c.out.val)
      verifyEq(c.startIndex, 3)
      verifyEq(c.afterIndex, 6)

      setAndExec(c, "inB", ss("baz"))
      verify(c.out.val)
      verifyEq(c.startIndex, 6)
      verifyEq(c.afterIndex, 9)

      setAndExec(c, "inB", ss("foo"))
      c.fromIndex = 1; cs.execute
      verifyFalse(c.out.val)
      verifyEq(c.startIndex, -1)
      verifyEq(c.afterIndex, -1)
    }
  }

  Void testStrLen()
  {
    TestHxCompContext().asCur |cx|
    {
      StrLen c := createAndExec("StrLen")
      verifyEq(c.out, sn(0))
      setAndExec(c, "in", ss(""))
      verifyEq(c.out, sn(0))
      setAndExec(c, "in", ss("a"))
      verifyEq(c.out, sn(1))
      setAndExec(c, "in", ss("ab"))
      verifyEq(c.out, sn(2))
      setAndExec(c, "in", null)
      verifyEq(c.out, sn(0))
    }
  }

  Void testStrSubstr()
  {
    TestHxCompContext().asCur |cx|
    {
      StrSubstr c := createComp("StrSubstr")
      cs.root.add(c)
      verifyEq(c.out, ss(""))

      setAndExec(c, "in", ss("foobarbaz"))
      verifyEq(c.out, ss("foobarbaz"))

      c.startIndex = 1; cs.execute
      verifyEq(c.out, ss("oobarbaz"))

      c.endIndex = 3; cs.execute
      verifyEq(c.out, ss("oo"))

      c.endIndex = -2; cs.execute
      verifyEq(c.out, ss("oobarba"))
    }
  }

  Void testStrTrim()
  {
    TestHxCompContext().asCur |cx|
    {
      StrTrim c := createAndExec("StrTrim")
      verifyEq(c.out, ss(""))

      setAndExec(c, "in", ss(""))
      verifyEq(c.out, ss(""))

      setAndExec(c, "in", ss(" \t\n\ra \t\n\r"))
      verifyEq(c.out, ss("a"))

      setAndExec(c, "in", null)
      verifyEq(c.out, ss(""))
    }
  }

  Void testStrTest()
  {
    TestHxCompContext().asCur |cx|
    {
      StrTest c := createAndExec("StrTest")
      verifyFalse(c.out.val)

      setAndExec(c, "inA", ss("foobarbaz"))
      verifyFalse(c.out.val)

      // eq
      setAndExec(c, "inB", ss("foo"))
      verifyFalse(c.out.val)
      setAndExec(c, "inB", ss("foobarbaz"))
      verify(c.out.val)

      // eqIgnoreCase
      c.test = StrTestType.eqIgnoreCase
      verify(c.out.val)
      setAndExec(c, "inB", ss("foo"))
      verifyFalse(c.out.val)
      setAndExec(c, "inB", ss("FOOBARBAZ"))
      verify(c.out.val)

      // startsWith
      c.test = StrTestType.startsWith; cs.execute
      verifyFalse(c.out.val)
      setAndExec(c, "inB", ss("foo"))
      verify(c.out.val)

      // endsWith
      c.test = StrTestType.endsWith; cs.execute
      verifyFalse(c.out.val)
      setAndExec(c, "inB", ss("baz"))
      verify(c.out.val)

      // continas
      c.test = StrTestType.contains; cs.execute
      verify(c.out.val)
      setAndExec(c, "inB", ss("nope"))
      verifyFalse(c.out.val)
    }
  }
}