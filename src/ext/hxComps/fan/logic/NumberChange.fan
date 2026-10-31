//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

**
** Detects a change of a number input: `out` is true for one execute after
** `in` differs from its previous value, `up` when it rose and `down` when
** it fell, and all three are false otherwise.  They clear on the next
** cycle even when nothing else changes.  The values are compared as floats
** and the unit is ignored.  This is the CDL `Integers.Change` block.
**
** A null `in` sets the outputs to null and keeps the previous `in`.  An
** invalid `in` is not compared, and the outputs are false with its status,
** or stay null after a null.  A NaN `in` with a valid status is a fault,
** and so is a NaN `initPrev` before the first comparison, whatever the
** status of `in`.  A fault gives false outputs with the status of `in`
** plus fault.  After a restart the first valid execute compares `in` with
** `initPrev` again.
**
@Gen
class NumberChange : Logic
{
  ** Input to watch
  @Gen virtual StatusNumber? in() { get("in") }

  ** The previous value of `in` assumed by the first execute
  @Gen virtual Number initPrev { get {get("initPrev")} set {set("initPrev", it)} }

  ** True for one execute after `in` rose
  @Gen virtual StatusBool? up() { get("up") }

  ** True for one execute after `in` fell
  @Gen virtual StatusBool? down() { get("down") }

  private Bool initialized
  private Float lastIn

  override Void onExecute()
  {
    u := in

    if (u == null) return write(null, null, Status.ok)

    // a configuration fault shows whatever the status of in
    if (!initialized && initPrev.isNaN)
      return write(false, false, u.status.set(Status.fault))

    if (!u.status.isValid)
    {
      if (get("out") != null) write(false, false, u.status)
      return
    }

    if (u.num.isNaN) return write(false, false, u.status.set(Status.fault))

    cur := u.num.toFloat
    pre := initialized ? lastIn : initPrev.toFloat
    initialized = true
    lastIn = cur

    cmp := cur <=> pre
    write(cmp > 0, cmp < 0, u.status)

    // a pulse lasts one execute: run the next cycle to clear it
    if (cmp != 0) execute
  }

  private Void write(Bool? up, Bool? down, Status status)
  {
    if (up == null)
    {
      set("out", null); set("up", null); set("down", null)
      return
    }
    set("out",  StatusBool(up || down, status))
    set("up",   StatusBool(up, status))
    set("down", StatusBool(down, status))
  }
}
