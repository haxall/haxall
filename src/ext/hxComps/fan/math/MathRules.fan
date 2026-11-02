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
** The helpers of the CDL math components, which check in one order.  A
** null input sets `out` to null.  Then an input with an invalid status
** sets it to NaN with the merged status and no unit.  Then, with valid
** inputs, units that do not convert and configuration errors give NaN
** with fault and no unit.  Otherwise `out` is what the arithmetic gives,
** an infinity included, as in `BinaryMath`.  A NaN the arithmetic gives,
** or a domain error such as a psychrometric input out of range, gives NaN
** with no fault added, in the unit `out` would have, as `BinaryMath`
** keeps the unit of a NaN it computes.
**
internal const class MathRules
{
  ** False for NaN, +INF and -INF
  static Bool finite(Float x) { !x.isNaN && x != Float.posInf && x != Float.negInf }

  ** `x`, in the unit `u`, in the base unit of its dimension, offset
  ** included: kelvin for a temperature.  `x` itself for no unit.
  static Float base(Float x, Unit? u)
  {
    u == null ? x : x * u.scale + u.offset
  }

  ** The first non-null unit, or null
  static Unit? firstUnit(Unit?[] units)
  {
    units.find |u| { u != null }
  }

  ** The value of `n` in the unit `to` as a point, offset included, a null
  ** unit being the other one.  Null when the units do not convert.
  static Float? pointIn(Number n, Unit? to)
  {
    u := n.unit
    if (u == null || to == null || u == to) return n.toFloat
    if (u.dim != to.dim || isDelta(u) != isDelta(to)) return null
    return u.convertTo(n.toFloat, to)
  }

  ** As `pointIn`, but only a scale converts: `ft` to `m` fits, `°C` to
  ** `°F` does not
  static Float? magnitudeIn(Number n, Unit? to)
  {
    u := n.unit
    if (u == null || to == null || u == to) return n.toFloat
    if (u.dim != to.dim || u.offset != 0f || to.offset != 0f || isDelta(u) != isDelta(to)) return null
    return u.convertTo(n.toFloat, to)
  }

  ** A temperature difference such as `Δ°F`
  static Bool isDelta(Unit u) { u.symbol.startsWith("Δ") }

  ** Write NaN to out with `status`, in `unit`: none for an invalid input,
  ** and the unit `out` would have for a NaN the comp computes
  static Void nan(Comp c, Status status, Unit? unit := null)
  {
    c.set("out", StatusNumber(Number(Float.nan, unit), status))
  }

  ** Write NaN to out with `status` plus fault, with no unit
  static Void fault(Comp c, Status status)
  {
    nan(c, status.set(Status.fault))
  }
}
