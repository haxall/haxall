//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   01 Aug 2025  Matthew Giannini  Creation
//

using xeto

**
** A "rising-edge" latch
**
abstract class Latch : HxComp
{
  /* ionc-start */

  ** When the clock transitions from false to true it will cause
  ** out to be set to current value of in.
  virtual Bool clock { get {get("clock")} set {set("clock", it)} }

  ** The input status value. The output will be set when the clock
  ** transitions from false to true.
  virtual StatusVal? in() { get("in") }

  ** The latched output
  virtual StatusVal? out() { get("out") }

  /* ionc-end */

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
** A Bool latch
**
class BoolLatch : Latch
{
  /* ionc-start */

  override StatusBool? in() { get("in") }

  override StatusBool? out() { get("out") }

  /* ionc-end */
}

**
** A Number latch
**
class NumberLatch : Latch
{
  /* ionc-start */

  override StatusNumber? in() { get("in") }

  override StatusNumber? out() { get("out") }

  /* ionc-end */
}

**
** A Str latch
**
class StrLatch : Latch
{
  /* ionc-start */

  override StatusStr? in() { get("in") }

  override StatusStr? out() { get("out") }

  /* ionc-end */
}

