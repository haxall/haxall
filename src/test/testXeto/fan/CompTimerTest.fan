//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using xetom
using haystack

**
** CompTimerTest checks when the onExecuteFreq timer executes a comp.
** A 1min TestCounter has no inputs, so only the timer executes it.
**
class CompTimerTest : AbstractXetoTest
{
  ** The timer fires each minute from the last fire, and on a forward step
  Void testTimer()
  {
    verifyEq(run(secs(0, 200)), [0, 60, 120, 180])
    verifyEq(run(secs(0, 203, 7)), [0, 63, 126, 189])
    verifyEq(run(secs(0, 30).addAll(secs(3630, 3760))), [0, 3630, 3690, 3750])
    verifyEq(run(secs(0, 10).add("off").addAll(secs(11, 100)).add("on").addAll(secs(101, 170))), [0, 101, 161])
  }

  ** A step back of the clock counts as no time
  Void testClockBack()
  {
    verifyEq(run(secs(0, 30).addAll(secs(27, 130))), [0, 57, 117])
    verifyEq(run(secs(0, 61).addAll(secs(58, 180))), [0, 60, 117, 177])
    verifyEq(run(secs(0, 30).add(27).addAll(secs(24, 120))), [0, 54, 114])
    verifyEq(run(secs(0, 61).addAll(secs(-3539, -3400))), [0, 60, -3480, -3420])
    verifyEq(run(secs(0, 10).add("off").addAll(secs(11, 20)).addAll(secs(-3580, -1780, 10))
      .add("on").addAll(secs(-1779, -1700))), [0, -1779, -1719])
  }

  static Obj[] secs(Int from, Int to, Int step := 1)
  {
    acc := Obj[,]
    for (t := from; t <= to; t += step) acc.add(t)
    return acc
  }

  ** Run a cycle at each offset in seconds, or toggle the timer "off" and
  ** "on", and return the offsets at which the counter executed
  Int[] run(Obj[] plan)
  {
    cs := CompSpace(createNamespace(CompTest.loadTestLibs)).install.start
    try
    {
      cs.loadXeto(Str<|@root: TestFolder { a @a: TestCounter {} }|>)
      a := (TestCounter)cs.root->a
      t0 := DateTime.now.floor(1sec) - 1day
      acc := Int[,]
      TestAxonContext(cs.ns).asCur |cx|
      {
        plan.each |p|
        {
          if (p == "off") { a.freq = null; return }
          if (p == "on")  { a.freq = 1min; return }
          before := ((TestVal)a["out"]).val
          cx.now = t0 + Duration(((Int)p) * 1sec.ticks)
          cs.execute
          if (((TestVal)a["out"]).val != before) acc.add(p)
        }
      }
      return acc
    }
    finally CompSpace.uninstall
  }
}
