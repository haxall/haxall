//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

class UtilTest : HxCompTest
{
  Void testRandom()
  {
    SimulatedCompContext(cs).asCur |cx|
    {
      ts := cx.now

      Random r := createComp("Random")
      cs.root.add(r)
      cx.step(ts)

      prev := -1f
      10.times |x|
      {
        cx.step(ts + (r.freq * (x+1)))

        rand := r.out.num.toFloat
        verify(0f <= rand && rand <= 1.0f)
        verify(rand != prev)

        prev = rand
      }
    }
  }
}