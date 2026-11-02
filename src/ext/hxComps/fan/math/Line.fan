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
** Computes `out` on the line through the points (`inX1`, `inF1`) and
** (`inX2`, `inF2`), at `in`.  With `limitBelow`, `in` is first raised to
** `inX1` when below it, and with `limitAbove` lowered to `inX2` when above
** it.  This is the CDL `Reals.Line` block.  `in`, `inX1` and `inX2` are on
** one axis, and `inF1` and `inF2` on the other.  On each axis the first
** input with a unit, in that order, sets the unit, a unitless input is in
** that unit, and the others convert to it.  `out` has the unit of the
** second axis, a NaN included, but NaN for an invalid input or with fault
** has no unit.  A null input sets `out` to null, and an invalid input sets
** it to NaN with the merged status.  A unit that does not convert, such as
** `Δ°F` against a temperature, gives NaN with fault.  So does an `inX2` not
** above `inX1` while a limit is on, a NaN `inX1` or `inX2` included.
** Otherwise `out` is what the arithmetic gives, with no fault added, which
** can be infinite or NaN, as for an `inX1` equal to `inX2` with both limits
** off.  With a limit on, an `in` beyond it gives the value at that end, an
** infinite `in` included.
**
** Departing from MBL (the Modelica Buildings Library), an `inX2` not
** above `inX1` while a limit is on gives NaN with fault, where MBL warns.
**
@Gen
class Line : Math
{
  ** The independent value, CDL `u`
  @Gen virtual StatusNumber? in() { get("in") }

  ** The x of the first point, CDL `x1`
  @Gen virtual StatusNumber? inX1() { get("inX1") }

  ** The value at `inX1`, CDL `f1`
  @Gen virtual StatusNumber? inF1() { get("inF1") }

  ** The x of the second point, CDL `x2`
  @Gen virtual StatusNumber? inX2() { get("inX2") }

  ** The value at `inX2`, CDL `f2`
  @Gen virtual StatusNumber? inF2() { get("inF2") }

  ** Raise `in` to `inX1` when it is below it, CDL `limitBelow`
  @Gen virtual Bool limitBelow { get {get("limitBelow")} set {set("limitBelow", it)} }

  ** Lower `in` to `inX2` when it is above it, CDL `limitAbove`
  @Gen virtual Bool limitAbove { get {get("limitAbove")} set {set("limitAbove", it)} }

  override Void onExecute()
  {
    xs := [in, inX1, inX2]
    fs := [inF1, inF2]
    if (xs.any { it == null } || fs.any { it == null }) return set("out", null)

    status := Status.ok
    xs.each |sn| { status = status.merge(sn.status) }
    fs.each |sn| { status = status.merge(sn.status) }
    if (!status.isValid) return MathRules.nan(this, status)

    xu := MathRules.firstUnit(xs.map |sn->Unit?| { sn.num.unit })
    fu := MathRules.firstUnit(fs.map |sn->Unit?| { sn.num.unit })
    x := xs.map |sn->Float?| { MathRules.pointIn(sn.num, xu) }
    f := fs.map |sn->Float?| { MathRules.pointIn(sn.num, fu) }
    if (x.any { it == null } || f.any { it == null }) return MathRules.fault(this, status)

    u  := (Float)x[0]
    x1 := (Float)x[1]
    x2 := (Float)x[2]
    f1 := (Float)f[0]
    f2 := (Float)f[1]

    // Line.mo: if limitBelow or limitAbove then assert(x2 > x1), which a
    // NaN x1 or x2 fails
    below := limitBelow
    above := limitAbove
    if ((below || above) && !(x2 > x1)) return MathRules.fault(this, status)

    b := (f2 - f1) / (x2 - x1)
    a := f2 - b * x2
    xLim := u
    if (below && xLim < x1) xLim = x1
    if (above && xLim > x2) xLim = x2
    y := a + b * xLim
    if (y.isNaN) return MathRules.nan(this, status, fu)

    set("out", StatusNumber(Number(y, fu), status))
  }
}
