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
** Converts a number to a bool with hysteresis: `out` turns true when
** `in` > `high` and false when `in` < `low`.  This is the CDL
** `Reals.Hysteresis` block.  Nulls, invalid statuses and faults are
** handled as for `ComparisonHys`.  These are faults whatever the status
** of `in`: a `high` not greater than `low`, a NaN limit, and limits
** whose units differ from each other or from `in`, where a unitless
** value fits any unit.
**
@Gen
class Hysteresis : Logic
{
  ** Input
  @Gen virtual StatusNumber? in() { get("in") }

  ** `out` turns false when `in` drops below this value.
  @Gen virtual Number low { get {get("low")} set {set("low", it)} }

  ** `out` turns true when `in` rises above this value.
  @Gen virtual Number high { get {get("high")} set {set("high", it)} }

  ** The previous value of `out` assumed by the first execute.
  @Gen virtual Bool initOut { get {get("initOut")} set {set("initOut", it)} }

  private Bool initialized
  private Bool outVal

  override Void onExecute()
  {
    u := in

    if (u == null) return set("out", null)

    status := u.status
    pre := initialized ? outVal : initOut

    // a configuration fault shows whatever the status of in
    lo := low
    hi := high
    if (isFault(u.num, lo, hi)) return write(pre, status.set(Status.fault))

    // an invalid in holds out, null included
    if (!status.isValid)
    {
      if (initialized && out != null) write(outVal, status)
      return
    }

    if (u.num.isNaN) return write(pre, status.set(Status.fault))

    v := u.num
    write((!pre && v > hi) || (pre && v >= lo), status)
  }

  ** Written as !(hi > lo) so a NaN limit faults too
  private static Bool isFault(Number u, Number lo, Number hi)
  {
    if (!(hi.toFloat > lo.toFloat)) return true
    return !fits(lo.unit, u.unit) || !fits(hi.unit, u.unit) || !fits(lo.unit, hi.unit)
  }

  private static Bool fits(Unit? x, Unit? y) { x == null || y == null || x == y }

  private Void write(Bool v, Status status)
  {
    this.initialized = true
    this.outVal = v
    set("out", StatusBool(v, status))
  }
}
