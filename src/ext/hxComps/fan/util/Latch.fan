//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   01 Aug 2025  Matthew Giannini  Creation
//

using xeto

**
** "Rising-edge" latch
**
@Gen
abstract class Latch : HxComp
{
  ** When the clock transitions from false to true it will cause
  ** out to be set to current value of in.
  @Gen virtual Bool clock { get {get("clock")} set {set("clock", it)} }

  ** The input status value. The output will be set when the clock
  ** transitions from false to true.
  @Gen virtual StatusVal? in() { get("in") }

  ** The latched output
  @Gen virtual StatusVal? out() { get("out") }

  new make() { }

  override Void onChange(CompChangeEvent e)
  {
    if ("clock" == e.name)
    {
      curClock := this.clock
      // check transition to true from false
      if (curClock && !this.lastClock)
      {
        set("out", get("in"))
      }
      this.lastClock = curClock
    }
  }

  private Bool lastClock
}

**
** Bool latch
**
@Gen
class BoolLatch : Latch
{
  @Gen override StatusBool? in() { get("in") }

  @Gen override StatusBool? out() { get("out") }
}

**
** Number latch
**
@Gen
class NumberLatch : Latch
{
  @Gen override StatusNumber? in() { get("in") }

  @Gen override StatusNumber? out() { get("out") }
}

**
** Str latch
**
@Gen
class StrLatch : Latch
{
  @Gen override StatusStr? in() { get("in") }

  @Gen override StatusStr? out() { get("out") }
}

