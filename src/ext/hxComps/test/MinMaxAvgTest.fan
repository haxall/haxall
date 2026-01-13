//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   07 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

class MinMaxAvgTest : HxCompTest
{
  Void test()
  {
    TestHxCompContext().asCur |cx|
    {
      MinMaxAvg c := createAndExec("MinMaxAvg")
      verifyNull(c.min); verifyNull(c.max); verifyNull(c.avg)

      setAndExec(c, "inA", sn(1))
      verifyEq(c.min, sn(1))
      verifyEq(c.max, sn(1))
      verifyEq(c.avg, sn(1))

      setAndExec(c, "inA", null)
      setAndExec(c, "inB", sn(2))
      setAndExec(c, "inD", sn(4))
      verifyEq(c.min, sn(2))
      verifyEq(c.max, sn(4))
      verifyEq(c.avg, sn(3))
    }
  }
}