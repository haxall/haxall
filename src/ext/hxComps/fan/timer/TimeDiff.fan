//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jun 2025  Matthew Giannini  Creation
//

using xeto
using haystack

**
** Computes the difference in time between `in1` and `in2` by subtracting
** `in2` from `in1`.
**
@Gen
class TimeDiff : HxComp
{
  ** The base time from which `in2` will be subtracted
  @Gen virtual DateTime in1() { get("in1") }

  ** The time to subtract from `in1`
  @Gen virtual DateTime in2() { get("in2") }

  ** The time difference between `in1` and `in2`
  @Gen virtual Duration out() { get("out") }

  new make()
  {
  }

  override Void onExecute()
  {
    set("out", in1 - in2)
  }
}

