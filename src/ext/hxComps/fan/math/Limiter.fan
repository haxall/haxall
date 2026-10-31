//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

**
** Limits `in` to the range from `uMin` to `uMax`:
** out = min(uMax, max(uMin, in)).  This is the CDL `Reals.Limiter` block.
** The first of `in`, `uMax` and `uMin` with a unit sets the unit, a
** unitless value is in that unit, and the others convert to it, so a limit
** in °C fits an `in` in °F.  `out` has the unit of `in`, a NaN included,
** but NaN for an invalid `in` or with fault has no unit.  A null `in` sets
** `out` to null and an invalid `in` sets it to NaN with its status.  `uMax`
** and `uMin` have no default, and `out` is NaN with fault until both are
** set.  A NaN limit, a `uMin` above `uMax` and a unit that does not
** convert, such as `Δ°F` against a temperature, give NaN with fault.
** Limits in one unit compare exactly, so a crossing of any size faults.
** Limits in two units compare in the base unit, kelvin for a temperature,
** where limits within 1E-9 of each other, relative to their size, are
** equal, as 5 °C and 41 °F, or 0 °C and 32 °F, are after unit conversion.
** Equal limits give that value, which ASHRAE 231 section 7.5.67 allows and
** MBL (the Modelica Buildings Library) rejects.  An infinite limit is no
** limit on its side, and equal infinite limits give that infinity.  An
** infinite `in` is limited as any other, and a NaN `in` gives NaN with no
** fault.
**
@Gen
class Limiter : Math
{
  ** The value to limit, CDL `u`
  @Gen virtual StatusNumber? in() { get("in") }

  ** The upper limit, CDL `uMax`.  It must not be below `uMin`.
  @Gen virtual Number? uMax { get {get("uMax")} set {set("uMax", it)} }

  ** The lower limit, CDL `uMin`
  @Gen virtual Number? uMin { get {get("uMin")} set {set("uMin", it)} }

  override Void onExecute()
  {
    x := in
    if (x == null) return set("out", null)

    status := x.status
    if (!status.isValid) return MathRules.nan(this, status)

    // an unset limit faults, as CDL gives the limits no default
    max := uMax
    min := uMin
    if (max == null || min == null) return MathRules.fault(this, status)

    axis := MathRules.firstUnit([x.num.unit, max.unit, min.unit])
    hi := MathRules.pointIn(max, axis)
    lo := MathRules.pointIn(min, axis)
    if (hi == null || lo == null || hi.isNaN || lo.isNaN) return MathRules.fault(this, status)

    // crossed limits fault.  Limits in one unit, a unitless limit being in
    // the axis unit, compare as given, so a crossing of any size faults,
    // and the conversion to the axis keeps them in order.  Limits in two
    // units that conversion leaves a few float steps apart are equal.
    // They are compared in the base unit, so a limit at the zero of an
    // offset unit, such as 0 °C, keeps its tolerance.  An infinite limit
    // is no limit, and crossed infinite limits fault.
    if ((max.unit ?: axis) == (min.unit ?: axis))
    {
      if (min.toFloat > max.toFloat) return MathRules.fault(this, status)
    }
    else if (lo > hi)
    {
      hiB := MathRules.base(hi, axis)
      loB := MathRules.base(lo, axis)
      if (!MathRules.finite(hiB) || !MathRules.finite(loB) || loB - hiB > tol * hiB.abs.max(loB.abs))
        return MathRules.fault(this, status)
      lo = hi
    }

    // in is in the axis unit already: the axis is its unit, or it has none.
    // An infinite in is clamped.
    u := x.num.toFloat
    if (u.isNaN) return MathRules.nan(this, status, x.num.unit)

    y := u > hi ? hi : (u < lo ? lo : u)
    set("out", StatusNumber(Number(y, x.num.unit), status))
  }

  ** The gap, relative to the limits in the base unit, within which crossed
  ** limits in two units count as equal
  private static const Float tol := 1E-9f
}
