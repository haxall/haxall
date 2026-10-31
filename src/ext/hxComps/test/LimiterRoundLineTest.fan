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
** Limiter, Round and Line
**
class LimiterRoundLineTest : MathCompTest
{

//////////////////////////////////////////////////////////////////////////
// Limiter
//////////////////////////////////////////////////////////////////////////

  ** Inside, at and beyond each limit, limits in another unit, null and invalid
  Void testLimiter()
  {
    run |->|
    {
      c := mk("Limiter", ["uMax":nu(10f), "uMin":nu(0f)])
      verifyOutNull(c)
      put(c, ["in":num(5f, null, Status.stale)]); verifyOut(c, Float.nan, null, Status.stale)
      put(c, ["in":num(5f)]);   verifyOut(c, 5f)
      put(c, ["in":num(10f)]);  verifyOut(c, 10f)
      put(c, ["in":num(11f)]);  verifyOut(c, 10f)
      put(c, ["in":num(-1f)]);  verifyOut(c, 0f)
      put(c, ["in":num(7f, null, Status.down)]); verifyOut(c, Float.nan, null, Status.down)
      put(c, ["in":num(Float.nan)]);    verifyOut(c, Float.nan)
      put(c, ["in":num(Float.negInf)]); verifyOut(c, 0f)
      put(c, ["in":num(Float.posInf)]); verifyOut(c, 10f)
      put(c, ["uMax":nu(30f, "°C"), "uMin":nu(50f), "in":num(100f, "°F")]); verifyOut(c, 86f, "°F")
      put(c, ["in":num(40f, "°F")]);   verifyOut(c, 50f, "°F")
      put(c, ["uMin":nu(10f, "Δ°F")]); verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["in":null]);             verifyOutNull(c)
    }
  }

  ** Equal limits give that value
  Void testLimiterEqual()
  {
    run |->|
    {
      c := mk("Limiter", ["uMax":nu(5f), "uMin":nu(5f), "in":num(3f)])
      verifyOut(c, 5f)
      put(c, ["in":num(7f)]); verifyOut(c, 5f)
    }
  }

  ** Equal limits in units that convert give that value: 5 °C and 41 °F
  Void testLimiterEqualUnits()
  {
    run |->|
    {
      c := mk("Limiter", ["uMax":nu(5f, "°C"), "uMin":nu(41f, "°F"), "in":num(3f, "°C")])
      verifyOut(c, 5f, "°C")
      put(c, ["in":num(7f, "°C")]);  verifyOut(c, 5f, "°C")
      put(c, ["in":num(30f, "°F")]); verifyOut(c, 41f, "°F")
      put(c, ["in":num(50f, "°F")]); verifyOut(c, 41f, "°F")
      put(c, ["uMax":nu(41f, "°F"), "uMin":nu(5f, "°C"), "in":num(3f, "°C")]); verifyOut(c, 5f, "°C")
      put(c, ["in":num(7f, "°C")]);  verifyOut(c, 5f, "°C")
      put(c, ["in":num(30f, "°F")]); verifyOut(c, 41f, "°F")
      put(c, ["in":num(50f, "°F")]); verifyOut(c, 41f, "°F")
      // 32 °F converts to a few float steps above 0 °C: equal in kelvin,
      // so not crossed
      put(c, ["uMax":nu(0f, "°C"), "uMin":nu(32f, "°F"), "in":num(3f, "°C")]); verifyOut(c, 0f, "°C")
      put(c, ["in":num(-3f, "°C")]); verifyOut(c, 0f, "°C")
      put(c, ["in":num(40f, "°F")]); verifyOut(c, 32f, "°F")
      put(c, ["uMax":nu(32f, "°F"), "uMin":nu(0f, "°C"), "in":num(3f, "°C")]); verifyOut(c, 0f, "°C")
      put(c, ["in":num(20f, "°F")]); verifyOut(c, 32f, "°F")
    }
  }

  ** Crossed limits in units that convert fault, however close: 0.0001 °F
  ** is about 2E-7 of 0 °C in kelvin
  Void testLimiterCrossedUnits()
  {
    run |->|
    {
      c := mk("Limiter", ["uMax":nu(0f, "°C"), "uMin":nu(32.0001f, "°F"), "in":num(3f, "°C")])
      verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["in":num(40f, "°F")]); verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMax":nu(31.9999f, "°F"), "uMin":nu(0f, "°C")]); verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMax":nu(5f, "°C"), "uMin":nu(41.0001f, "°F")]); verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMax":nu(273.15f, "K"), "uMin":nu(0.0001f, "°C")]); verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMin":nu(0f, "°C")]); verifyOut(c, 32f, "°F", Status.ok, 1e-9f)
    }
  }

  ** Limits in one unit compare exactly, so a crossing of any size faults:
  ** 0.1000001 °C is within 1E-9 of 0.1 °C in kelvin, and the float after
  ** 0.1 is equal to it in kelvin.  A unitless limit is in the axis unit,
  ** the first unit of `in`, `uMax` and `uMin`, even when `in` is unitless.
  Void testLimiterSameUnit()
  {
    run |->|
    {
      c := mk("Limiter", ["uMax":nu(0.1f, "°C"), "uMin":nu(0.1000001f, "°C"), "in":num(3f, "°C")])
      verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["in":num(40f, "°F")]); verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMin":nu(Float.makeBits(0.1f.bits + 1), "°C"), "in":num(3f, "°C")])
      verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["in":num(40f, "°F")]); verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMax":nu(0.1f), "uMin":nu(Float.makeBits(0.1f.bits + 1), "°C"), "in":num(3f, "°C")])
      verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMin":nu(Float.makeBits(0.1f.bits + 1)), "in":num(3f)])
      verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMin":nu(0.1f)]); verifyOut(c, 0.1f)
      // in unitless: the axis is the °C of uMin, so uMax is in °C too
      put(c, ["uMax":nu(0.1f), "uMin":nu(Float.makeBits(0.1f.bits + 1), "°C"), "in":num(3f)])
      verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMin":nu(0.1f, "°C")]); verifyOut(c, 0.1f)
    }
  }

  ** Limits in two units compare in the base unit within 1E-9 relative to
  ** its size, not an absolute 1E-9: 300.0000001 K against 26.85 °C, 300 K,
  ** is 1.0E-7 K apart, under the 3.0E-7 K the tolerance allows there
  Void testLimiterCrossUnitTolerance()
  {
    run |->|
    {
      c := mk("Limiter", ["uMax":nu(26.85f, "°C"), "uMin":nu(300.0000001f, "K"), "in":num(20f, "°C")])
      verifyOut(c, 26.85f, "°C")
      put(c, ["in":num(30f, "°C")]); verifyOut(c, 26.85f, "°C")
      put(c, ["in":num(300f, "K")]); verifyOut(c, 300f, "K", Status.ok, 1e-9f)
      // 1E-6 K apart is a crossing
      put(c, ["uMin":nu(300.000001f, "K"), "in":num(20f, "°C")]); verifyOut(c, Float.nan, null, Status.fault)
    }
  }

  ** A NaN `in` gives NaN in the unit of `in`, and an invalid `in` gives NaN
  ** with no unit
  Void testLimiterNaNUnit()
  {
    run |->|
    {
      c := mk("Limiter", ["uMax":nu(30f, "°C"), "uMin":nu(50f), "in":num(Float.nan, "°F")])
      verifyOut(c, Float.nan, "°F")
      put(c, ["in":num(Float.nan, "°F", Status.down)]); verifyOut(c, Float.nan, null, Status.down)
    }
  }

  ** The limits are checked before a NaN `in` gives NaN: unset and crossed
  ** limits fault.  An invalid `in` is checked before the limits and units:
  ** it gives NaN with no unit and its own status, with no fault added.
  Void testLimiterCheckOrder()
  {
    run |->|
    {
      c := mk("Limiter", ["in":num(Float.nan)])
      verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMax":nu(1f), "uMin":nu(2f)]); verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMin":nu(0f)]);                verifyOut(c, Float.nan)
      // unset limits
      put(c, ["uMax":null, "uMin":null, "in":num(5f, null, Status.down)])
      verifyOut(c, Float.nan, null, Status.down)
      put(c, ["in":num(5f)]); verifyOut(c, Float.nan, null, Status.fault)
      // a uMin in Δ°F, which does not convert to the °F of in
      put(c, ["uMax":nu(10f), "uMin":nu(10f, "Δ°F"), "in":num(5f, "°F", Status.down)])
      verifyOut(c, Float.nan, null, Status.down)
      put(c, ["in":num(5f, "°F")]); verifyOut(c, Float.nan, null, Status.fault)
    }
  }

  ** An infinite limit is no limit, equal infinite limits give that
  ** infinity, and crossed infinite limits fault
  Void testLimiterInfinite()
  {
    run |->|
    {
      c := mk("Limiter", ["uMax":nu(Float.posInf), "uMin":nu(Float.negInf), "in":num(5f)])
      verifyOut(c, 5f)
      put(c, ["in":num(Float.posInf)]); verifyOut(c, Float.posInf)
      put(c, ["in":num(Float.negInf)]); verifyOut(c, Float.negInf)
      put(c, ["in":num(Float.nan)]);    verifyOut(c, Float.nan)
      put(c, ["uMin":nu(1f), "in":num(Float.negInf)]); verifyOut(c, 1f)
      put(c, ["uMin":nu(Float.posInf), "in":num(5f)]); verifyOut(c, Float.posInf)
      put(c, ["in":num(Float.negInf)]); verifyOut(c, Float.posInf)
      put(c, ["uMax":nu(Float.negInf), "uMin":nu(Float.negInf)]); verifyOut(c, Float.negInf)
      put(c, ["in":num(5f)]);           verifyOut(c, Float.negInf)
      put(c, ["uMax":nu(3f), "uMin":nu(Float.posInf)]);  verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMax":nu(Float.negInf), "uMin":nu(1f)]);  verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMin":nu(Float.posInf)]); verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMax":nu(Float.posInf, "°C"), "uMin":nu(32f, "°F"), "in":num(50f, "°F")]); verifyOut(c, 50f, "°F")
      put(c, ["in":num(20f, "°F")]);    verifyOut(c, 32f, "°F")
      // crossed infinite limits in two units fault too
      put(c, ["uMax":nu(3f, "°C"), "uMin":nu(Float.posInf, "°F"), "in":num(5f, "°C")])
      verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMax":nu(Float.negInf, "°C"), "uMin":nu(1f, "°F")]); verifyOut(c, Float.nan, null, Status.fault)
    }
  }

  ** With no limits set the comp faults
  Void testLimiterUnset()
  {
    run |->|
    {
      c := mk("Limiter", ["in":num(2f)])
      verifyOut(c, Float.nan, null, Status.fault)
    }
  }

  ** The comp faults while either limit is unset
  Void testLimiterOneUnset()
  {
    run |->|
    {
      c := mk("Limiter", ["uMax":nu(3f), "in":num(2f)])
      verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMin":nu(1f)]);  verifyOut(c, 2f)
      put(c, ["uMax":null]);    verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMax":nu(3f)]);  verifyOut(c, 2f)
    }
  }

  ** A uMin above uMax and a NaN limit fault, and an infinite limit is no
  ** limit
  Void testLimiterAssert()
  {
    run |->|
    {
      c := mk("Limiter", ["in":num(2f), "uMax":nu(3f), "uMin":nu(1f)])
      verifyOut(c, 2f)  // 2 is inside 1 to 3
      // crossed and NaN limits give NaN with fault
      put(c, ["uMin":nu(4f)]);                verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMin":nu(Float.nan)]);         verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMin":nu(1f), "uMax":nu(Float.nan)]); verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["uMax":nu(3f), "uMin":nu(Float.negInf)]); verifyOut(c, 2f)
      put(c, ["uMin":nu(1f), "uMax":nu(Float.posInf)]); verifyOut(c, 2f)
      put(c, ["uMax":nu(3f)]);                verifyOut(c, 2f)
      // a down in gives NaN with its status, and the limits are not checked
      put(c, ["uMax":nu(3f), "in":num(5f, null, Status.down)]); verifyOut(c, Float.nan, null, Status.down)
      put(c, ["uMin":nu(4f)]);                verifyOut(c, Float.nan, null, Status.down)
      put(c, ["uMin":nu(1f), "in":num(5f)]);  verifyOut(c, 3f)  // min(3, max(1, 5))
    }
  }

//////////////////////////////////////////////////////////////////////////
// Round
//////////////////////////////////////////////////////////////////////////

  ** Halves round away from zero, a zero result is positive zero, units carry
  Void testRound()
  {
    run |->|
    {
      c := mk("Round")
      put(c, ["in":num(2.5f)]);  verifyOut(c, 3f)
      put(c, ["in":num(-2.5f)]); verifyOut(c, -3f)
      put(c, ["in":num(-1.6f)]); verifyOut(c, -2f)
      put(c, ["n":1, "in":num(1.25f)]);  verifyOut(c, 1.3f)
      put(c, ["in":num(-1.25f)]);        verifyOut(c, -1.3f)
      put(c, ["in":num(72.46f, "°F")]);  verifyOut(c, 72.5f, "°F")
      put(c, ["n":-1, "in":num(15f)]);   verifyOut(c, 20f)
      put(c, ["in":num(14.9f)]);         verifyOut(c, 10f)
      [-0.3f, negZero].each |u|
      {
        z := mk("Round", ["in":num(u)])
        verifyOut(z, 0f)
        verify(!outF(z).isNegZero, "round($u)")
      }
    }
  }

  ** out is what the formula gives: NaN for an n whose 10^n is 0 or
  ** infinite, an infinity for an overflow or an infinite in; and null and
  ** invalid inputs
  Void testRoundNaN()
  {
    run |->|
    {
      c := mk("Round", ["in":num(1.5f)]); verifyOut(c, 2f)
      put(c, ["n":400]);  verifyOut(c, Float.nan)
      put(c, ["n":-400]); verifyOut(c, Float.nan)
      // an invalid in gives its status whatever n is
      put(c, ["in":num(1.5f, null, Status.down)]); verifyOut(c, Float.nan, null, Status.down)
      // 1e300 * 10^10 overflows to inf, and inf / 10^10 is inf
      put(c, ["n":10, "in":num(1e300f)]);  verifyOut(c, Float.posInf)
      put(c, ["in":num(-1e300f)]);         verifyOut(c, Float.negInf)
      put(c, ["n":0, "in":num(-2.5f, null, Status.down)]); verifyOut(c, Float.nan, null, Status.down)
      put(c, ["in":num(Float.nan)]);    verifyOut(c, Float.nan)
      put(c, ["in":num(Float.posInf)]); verifyOut(c, Float.posInf)
      put(c, ["in":num(Float.negInf, "°F")]); verifyOut(c, Float.negInf, "°F")
      put(c, ["in":null]);              verifyOutNull(c)
    }
  }

  ** A NaN the formula gives is in the unit of `in`, and an invalid `in`
  ** gives NaN with no unit
  Void testRoundNaNUnit()
  {
    run |->|
    {
      c := mk("Round", ["in":num(Float.nan, "°F")]); verifyOut(c, Float.nan, "°F")
      put(c, ["n":400, "in":num(1.5f, "°F")]);  verifyOut(c, Float.nan, "°F")
      put(c, ["n":-400]);                       verifyOut(c, Float.nan, "°F")
      put(c, ["in":num(1.5f, "°F", Status.down)]); verifyOut(c, Float.nan, null, Status.down)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Line
//////////////////////////////////////////////////////////////////////////

  ** The line through (0, 0) and (10, 100), with each limit on and off
  Void testLine()
  {
    run |->|
    {
      c := mk("Line", ["inX1":num(0f), "inF1":num(0f), "inX2":num(10f), "inF2":num(100f)])
      put(c, ["in":num(5f)]);       verifyOut(c, 50f)
      put(c, ["in":num(-5f)]);      verifyOut(c, 0f)
      put(c, ["in":num(15f)]);      verifyOut(c, 100f)
      put(c, ["limitAbove":false]); verifyOut(c, 150f)
      put(c, ["limitBelow":false, "in":num(-5f)]); verifyOut(c, -50f)
      put(c, ["limitAbove":true, "in":num(15f)]);  verifyOut(c, 100f)
    }
  }

  ** An inX2 not above inX1 faults while a limit is on, and with no limit
  ** an inX1 equal to inX2 gives NaN with status ok
  Void testLineX2NotAboveX1()
  {
    run |->|
    {
      c := mk("Line", ["in":num(5f), "inX1":num(10f), "inF1":num(0f), "inX2":num(0f), "inF2":num(100f)])
      verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["limitBelow":false]); verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["limitAbove":false]); verifyOut(c, 50f)
      put(c, ["inX2":num(10f)]);    verifyOut(c, Float.nan)
      put(c, ["limitAbove":true]);  verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["inX1":num(0f), "limitBelow":true]); verifyOut(c, 50f)
    }
  }

  ** The inX2 above inX1 assert runs ahead of a NaN in, and after an
  ** invalid input
  Void testLineCheckOrder()
  {
    run |->|
    {
      c := mk("Line", ["in":num(Float.nan), "inX1":num(10f), "inF1":num(0f), "inX2":num(0f), "inF2":num(100f)])
      verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["limitAbove":false]); verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["in":num(5f, null, Status.down)]); verifyOut(c, Float.nan, null, Status.down)
      put(c, ["limitBelow":false]); verifyOut(c, Float.nan, null, Status.down)
      put(c, ["in":num(Float.nan)]); verifyOut(c, Float.nan)
      put(c, ["inX2":num(Float.nan), "inX1":num(0f), "limitBelow":true]); verifyOut(c, Float.nan, null, Status.fault)
    }
  }

  ** With a limit on, an infinite in gives the value at that end; with it
  ** off, out is what the arithmetic gives
  Void testLineInfinite()
  {
    run |->|
    {
      c := mk("Line", ["in":num(Float.posInf), "inX1":num(0f), "inF1":num(0f), "inX2":num(10f), "inF2":num(100f)])
      verifyOut(c, 100f)
      put(c, ["in":num(Float.negInf)]); verifyOut(c, 0f)
      put(c, ["limitBelow":false]);     verifyOut(c, Float.negInf)
      put(c, ["in":num(Float.posInf)]); verifyOut(c, 100f)
      put(c, ["limitAbove":false]);     verifyOut(c, Float.posInf)
      put(c, ["limitBelow":true, "in":num(Float.negInf)]); verifyOut(c, 0f)
      // a flat line off its limits takes 0 * inf
      put(c, ["limitBelow":false, "inF2":num(0f)]); verifyOut(c, Float.nan)
    }
  }

  ** Each axis converts to its first unit, out has the unit of the second
  ** axis, a NaN result included, and null, invalid and non-finite inputs
  Void testLineUnitsNullInvalid()
  {
    run |->|
    {
      c := mk("Line", ["in":num(60f, "°F"), "inX1":num(10f, "°C"), "inF1":num(0f),
                       "inX2":num(70f, "°F"), "inF2":num(100f, "%")])
      verifyOut(c, 50f, "%", Status.ok, 1e-9f)
      ["in", "inX1", "inF1", "inX2", "inF2"].each |n|
      {
        old := c.get(n)
        put(c, [n:null]); verifyOutNull(c, n)
        put(c, [n:old]);  verifyOut(c, 50f, "%", Status.ok, 1e-9f)
      }
      put(c, ["inX2":num(70f, "Δ°F")]); verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["inX2":num(70f, "°F"), "in":num(65f, null, Status.down)]); verifyOut(c, Float.nan, null, Status.down)
      put(c, ["inF2":num(100f, "%", Status.stale)]); verifyOut(c, Float.nan, null, Status.down.merge(Status.stale))
      put(c, ["inF2":num(100f, "%"), "in":num(Float.nan)]); verifyOut(c, Float.nan, "%")
      put(c, ["in":num(60f, "°F"), "inF1":num(Float.posInf)]); verifyOut(c, Float.nan, "%")
    }
  }
}
