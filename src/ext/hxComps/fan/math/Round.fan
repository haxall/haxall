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
** Rounds `in` to `n` decimal places, with a half rounded away from zero:
** out = floor(in*f + 0.5)/f when `in` is above 0, and ceil(in*f - 0.5)/f
** otherwise, with f = 10^n.  An `n` of -1 rounds to a multiple of ten.
** This is the CDL `Reals.Round` block, and with `n` 0 the CDL
** `Conversions.RealToInteger` block, whose integer `out` is here a whole
** number.  `out` has the unit of `in`, a NaN included, but NaN for an
** invalid `in` has no unit.  A null `in` sets `out` to null and an invalid
** `in` sets it to NaN with its status.  Otherwise `out` is what the formula
** gives, with no fault added.  An `n` whose 10^n is 0 or infinite in a
** float gives NaN.  With any other `n`, an infinite `in` gives that
** infinity, as does an `in` whose in*f overflows, and a NaN `in` gives NaN.
**
** Departing from MBL (the Modelica Buildings Library), a zero result is
** positive zero.
**
@Gen
class Round : Math
{
  ** The value to round, CDL `u`
  @Gen virtual StatusNumber? in() { get("in") }

  ** The number of decimal places, CDL `n`
  @Gen virtual Int n { get {get("n")} set {set("n", it)} }

  override Void onExecute()
  {
    x := in
    if (x == null) return set("out", null)

    status := x.status
    if (!status.isValid) return MathRules.nan(this, status)

    // ceil gives -0.0 for a u in (-0.5, 0], made 0 below.  A fac of 0 or
    // INF, and a NaN u, give NaN.  With a finite nonzero fac, an infinite
    // u or u*fac gives ±INF.
    fac := 10f.pow(n.toFloat)
    u := x.num.toFloat
    y := u > 0f ? (u * fac + 0.5f).floor / fac : (u * fac - 0.5f).ceil / fac
    if (y.isNaN) return MathRules.nan(this, status, x.num.unit)

    set("out", StatusNumber(Number(y.normNegZero, x.num.unit), status))
  }
}
