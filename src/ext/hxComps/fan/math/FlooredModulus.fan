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
** Computes the remainder of `inA` divided by `inB`, with the quotient
** rounded toward negative infinity: out = inA - floor(inA / inB) * inB.
** This is the CDL `Reals.Modulo` block.  `out` has the sign of `inB`: -1
** modulo 3 is 2, where `Modulus` gives -1.  `inB` is converted to the unit
** of `inA` where the two differ only by a scale, such as `ft` for `m`, a
** unitless input fits any unit, and `out` has the unit of `inA`, a NaN
** included, but NaN for an invalid input or with fault has no unit.  As in
** `BinaryMath`, a null input sets `out` to null and an invalid input sets
** it to NaN with the merged status.  Other units, a temperature difference
** against a temperature included, give NaN with fault.  Otherwise `out` is
** what the formula gives, with no fault added.  A zero `inB` gives NaN, as
** in `Modulus`, and so does an infinite input, for which the formula takes
** infinity less infinity or zero times infinity.  Where `inA / inB`
** overflows, `out` is infinite, with the sign opposite to that of `inA`.
**
@Gen
class FlooredModulus : BinaryMath
{

  ** Modelica mod(x, y) = x - floor(x/y)*y with `b` in the unit of `a`
  protected override Number calculate(Number a, Number b)
  {
    unit := a.unit
    y := MathRules.magnitudeIn(b, unit) ?: throw UnitErr("$unit <=> $b.unit")
    x := a.toFloat
    r := x - (x / y).floor * y
    return Number(r, unit)
  }
}
