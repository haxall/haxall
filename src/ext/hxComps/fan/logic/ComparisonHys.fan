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
** The base spec for comparison operators with hysteresis.  A non-zero
** `deadband` keeps `out` from toggling while `inA` hovers near `inB`.
** For a fixed threshold, link a `NumberConst` to `inB`, since a value
** set on a transient slot is not saved.
**
** A null input sets `out` to null and keeps the state.  An invalid
** status holds the state and the value of `out`, and passes the merged
** status through.  A fault holds the state and gives the held value
** (`initOut` before the first value) with the merged status plus fault.
** These are faults: a negative or NaN `deadband` or a `deadband` unit
** that does not fit `inB`, whatever the input status, and a NaN input
** with a valid status.  `inA` and `inB` must have compatible units, as
** for `Comparison`.
**
@Gen
abstract class ComparisonHys : Logic
{
  ** Input A
  @Gen virtual StatusNumber? inA() { get("inA") }

  ** Input B
  @Gen virtual StatusNumber? inB() { get("inB") }

  ** Width of the hysteresis band, not negative, in the unit of `inB`, its
  ** delta unit (`°F` or `Δ°F` for an `inB` in `°F`), or unitless
  @Gen virtual Number deadband { get {get("deadband")} set {set("deadband", it)} }

  ** The previous value of `out` assumed by the first execute.
  @Gen virtual Bool initOut { get {get("initOut")} set {set("initOut", it)} }

  private Bool initialized
  private Bool outVal

  ** CDL have_hysteresis: a deadband below this is a plain comparison
  private static const Float minDeadband := 1E-10f

  final override Void onExecute()
  {
    a := inA
    b := inB

    if (a == null || b == null) return set("out", null)

    status := a.status.merge(b.status)
    pre := initialized ? outVal : initOut

    // a configuration fault shows whatever the input status
    h := deadband
    if (isFault(b.num, h)) return write(pre, status.set(Status.fault))

    // an invalid input holds out, null included
    if (!status.isValid)
    {
      if (initialized && out != null) write(outVal, status)
      return
    }

    if (a.num.isNaN || b.num.isNaN) return write(pre, status.set(Status.fault))

    hf := h.toFloat < minDeadband ? 0f : h.toFloat
    // incompatible inA and inB units hold out in fault, as Comparison does since 4.0.7
    try
      write(calculate(pre, a.num, b.num, hf), status)
    catch (UnitErr e)
      write(pre, status.set(Status.fault))
  }

  ** The deadband is a magnitude, so its unit may be the delta unit of inB
  private static Bool isFault(Number b, Number h)
  {
    if (h.isNaN || h.toFloat < 0f) return true
    hu := h.unit
    bu := b.unit
    if (hu == null || bu == null || hu == bu) return false
    return hu != Number.minusUnit(bu, bu)
  }

  ** Compute out from pre(out), A, B and the deadband in the unit of B
  protected abstract Bool calculate(Bool pre, Number a, Number b, Float h)

  private Void write(Bool v, Status status)
  {
    this.initialized = true
    this.outVal = v
    set("out", StatusBool(v, status))
  }
}

**
** Computes A > B with hysteresis: `out` turns true when A > B and false
** when A <= B - deadband.  This is the CDL `Reals.Greater` block, or
** `Reals.GreaterThreshold` with the threshold linked to `inB`.
**
@Gen
class GreaterThanHys : ComparisonHys
{
  ** B - h is built on floats: Number minus of two °F values gives Δ°F
  protected override Bool calculate(Bool pre, Number a, Number b, Float h)
  {
    (!pre && a > b) || (pre && a > Number(b.toFloat - h, b.unit))
  }
}

**
** Computes A < B with hysteresis: `out` turns true when A < B and false
** when A >= B + deadband.  This is the CDL `Reals.Less` block, or
** `Reals.LessThreshold` with the threshold linked to `inB`.
**
@Gen
class LessThanHys : ComparisonHys
{
  protected override Bool calculate(Bool pre, Number a, Number b, Float h)
  {
    (!pre && a < b) || (pre && a < Number(b.toFloat + h, b.unit))
  }
}
