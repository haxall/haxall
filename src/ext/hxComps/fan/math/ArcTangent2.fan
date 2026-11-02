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
** Computes the angle of the point (`inB`, `inA`) from the positive x axis:
** out = atan2(inA, inB), in radians from -pi to pi.  This is the CDL
** `Reals.Atan2` block, with `u1` on `inA` and `u2` on `inB`.  `inB` is
** converted to the unit of `inA` where the two differ only by a scale,
** such as `m` and `ft`, and a unitless input fits any unit.  `BinaryMath`
** converts no units, while the CDL math components convert as each one
** states.  As in `BinaryMath`, a null input sets `out` to null and an
** invalid input sets it to NaN with the merged status.  Other units, a
** temperature difference against a temperature included, give NaN with
** fault, a NaN or infinite input included.  Otherwise `out` is what atan2
** gives, with no fault added: an `inA` of +INF with a finite `inB` gives
** pi/2, and a NaN input gives NaN.
**
** Departing from MBL (the Modelica Buildings Library), `out` is unitless,
** as for the other trigonometry components, and 0 at the origin.  A zero
** input is read as positive zero, so `out` is pi on the negative x axis.
**
@Gen
class ArcTangent2 : BinaryMath
{

  ** atan2 with `b` in the unit of `a` and a negative zero read as positive
  ** zero
  protected override Number calculate(Number a, Number b)
  {
    bv := MathRules.magnitudeIn(b, a.unit) ?: throw UnitErr("$a.unit <=> $b.unit")
    return Number(Float.atan2(a.toFloat.normNegZero, bv.normNegZero))
  }
}
