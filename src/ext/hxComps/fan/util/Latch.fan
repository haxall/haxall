//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   01 Aug 2025  Matthew Giannini  Creation
//

using xeto

**
** "Rising-edge" latch.  The clock is read on execute, so `out` takes the
** value `in` has on the cycle the clock turns true.  A null or invalid
** `clock` holds `out`, and a rise is judged against the last valid
** `clock`.  A save with a Bool `clock` loads.  A plain Bool linked into
** `clock` is read with status ok and logged once.
**
@Gen
abstract class Latch : HxComp
{
  ** When the clock transitions from false to true it will cause
  ** out to be set to current value of in.
  @Gen virtual StatusBool? clock { get {get("clock")} set {set("clock", it)} }

  ** The input status value. The output will be set when the clock
  ** transitions from false to true.
  @Gen virtual StatusVal? in() { get("in") }

  ** The latched output
  @Gen virtual StatusVal? out() { get("out") }

  new make() { }

  override Void onExecute()
  {
    // a rise is judged against the last valid clock
    c := readClock
    if (c == null || !c.status.isValid) return

    // check transition to true from false
    if (c.val && !this.lastClock)
    {
      set("out", get("in"))
    }
    this.lastClock = c.val
  }

  ** The clock, with a plain Bool read as status ok and logged once
  private StatusBool? readClock()
  {
    raw := get("clock")
    if (raw isnot Bool) return raw
    if (!warnedBool)
    {
      this.warnedBool = true
      log.warn("${spec.name} @${id}.clock: plain Bool read as StatusBool ok; link a StatusBool output or put a BoolToStatusBool in the link (logged once)")
    }
    return StatusBool(raw, Status.ok)
  }

  private Bool lastClock

  private Bool warnedBool

  private static const Log log := Log.get("hxComps")
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

