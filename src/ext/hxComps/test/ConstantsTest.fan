//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jun 2025  Matthew Giannini  Creation
//

using haystack

class ConstantsTest : HxCompTest
{
  Void testBool()
  {
    TestHxCompContext().asCur |cx|
    {
      BoolConst b := createAndExec("BoolConst")
      verifyNull(b.out)

      b.out = StatusBool(true)
      cs.execute
      verifyEq(b.out, StatusBool(true))

      b.out = StatusBool(false)
      cs.execute
      verifyEq(b.out, StatusBool(false))
    }
  }

  Void testNumber()
  {
    TestHxCompContext().asCur |cx|
    {
      NumberConst n := createAndExec("NumberConst")
      verifyNull(n.out)

      n.out = StatusNumber(Number(123))
      cs.execute
      verifyEq(n.out, StatusNumber(Number(123)))
    }
  }

  Void testStr()
  {
    TestHxCompContext().asCur |cx|
    {
      StrConst s := createAndExec("StrConst")
      verifyNull(s.out)

      s.out = StatusStr("foo")
      cs.execute
      verifyEq(s.out, StatusStr("foo"))
    }

  }
}