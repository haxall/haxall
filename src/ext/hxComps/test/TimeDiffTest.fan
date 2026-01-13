//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jun 2025  Matthew Giannini  Creation
//

using haystack

class TimeDiffTest : HxCompTest
{
  Void test()
  {
    TestHxCompContext().asCur |cx|
    {
      TimeDiff diff := createComp("TimeDiff")
      cs.root.add(diff)
      cs.execute

      // initial state is no diff
      cs.execute
      verifyEq(0sec, diff.out)

      // update with same ts for in1 and in2
      ts := Date.today.midnight
      diff.set("in1", ts)
      diff.set("in2", ts)
      cs.execute
      verifyEq(0sec, diff.out)

      // in1 after in2
      diff.set("in1", ts + 1min)
      cs.execute
      verifyEq(1min, diff.out)

      // in2 after in1
      diff.set("in2", diff.in1 + 30sec)
      cs.execute
      verifyEq(-30sec, diff.out)
    }
  }
}