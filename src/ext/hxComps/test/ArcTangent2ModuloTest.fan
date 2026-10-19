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
** ArcTangent2 and FlooredModulus
**
class ArcTangent2ModuloTest : MathCompTest
{

//////////////////////////////////////////////////////////////////////////
// ArcTangent2
//////////////////////////////////////////////////////////////////////////

  ** The four quadrants, in radians
  Void testAtan2Quadrants()
  {
    run |->|
    {
      // out is the angle of the point (inB, inA): odd multiples of pi/4 on the diagonals
      c := mk("ArcTangent2")
      put(c, ["inA":num(1f),  "inB":num(1f)]);  verifyOut(c, Float.pi / 4f)
      put(c, ["inA":num(1f),  "inB":num(-1f)]); verifyOut(c, 3f * Float.pi / 4f)
      put(c, ["inA":num(-1f), "inB":num(-1f)]); verifyOut(c, -3f * Float.pi / 4f)
      put(c, ["inA":num(-1f), "inB":num(1f)]);  verifyOut(c, -Float.pi / 4f)
      // (4, 3) is atan(3/4) above the x axis, and (-3, 4) is pi less atan(4/3)
      put(c, ["inA":num(3f),  "inB":num(4f)]);  verifyOut(c, (3f / 4f).atan)
      put(c, ["inA":num(4f),  "inB":num(-3f)]); verifyOut(c, Float.pi - (4f / 3f).atan)
    }
  }

  ** 0 at the origin, and a zero input read as positive zero
  Void testAtan2Origin()
  {
    run |->|
    {
      verifyOut(mk("ArcTangent2", ["inA":num(0f), "inB":num(0f)]), 0f)
      verifyOut(mk("ArcTangent2", ["inA":num(negZero), "inB":num(negZero)]), 0f)
      verifyOut(mk("ArcTangent2", ["inA":num(negZero), "inB":num(-1f)]), Float.pi)
      verifyOut(mk("ArcTangent2", ["inA":num(0f), "inB":num(negZero)]), 0f)
      c := mk("ArcTangent2", ["inA":num(negZero), "inB":num(1f)])
      verifyOut(c, 0f)
      verify(!outF(c).isNegZero)
    }
  }

  ** out is unitless and inB converts by scale; other units, and null,
  ** invalid, NaN and infinite inputs
  Void testAtan2UnitsNullInvalid()
  {
    run |->|
    {
      c := mk("ArcTangent2")
      verifyOutNull(c)
      put(c, ["inA":num(1f, null, Status.down), "inB":num(1f)]); verifyOut(c, Float.nan, null, Status.down)
      put(c, ["inA":num(Float.nan)]); verifyOut(c, Float.nan)
      put(c, ["inA":num(1f, "m"), "inB":num(3.2808398950131234f, "ft")]); verifyOut(c, Float.pi / 4f)
      put(c, ["inA":num(1f), "inB":num(-1f, "ft")]);        verifyOut(c, 3f * Float.pi / 4f)
      put(c, ["inA":num(10f, "°F"), "inB":num(10f, "°C")]); verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["inA":num(1f, "K"), "inB":num(1f, "Δ°F")]);   verifyOut(c, Float.nan, null, Status.fault)
      // an invalid input gives NaN with its status, and its units are not checked
      put(c, ["inA":num(1f, "m", Status.down), "inB":num(1f, "s")]); verifyOut(c, Float.nan, null, Status.down)
      put(c, ["inA":num(-1f, null, Status.alarm), "inB":num(1f)]); verifyOut(c, -Float.pi / 4f, null, Status.alarm)
      put(c, ["inA":num(5f, null, Status.stale)]); verifyOut(c, Float.nan, null, Status.stale)
      // an infinite input gives atan2's angle
      put(c, ["inA":num(Float.posInf)]);           verifyOut(c, Float.pi / 2f)
      put(c, ["inB":num(Float.posInf)]);           verifyOut(c, Float.pi / 4f)
      put(c, ["inA":num(1f), "inB":num(Float.negInf)]); verifyOut(c, Float.pi)
      // units are checked before a NaN or infinite input computes
      put(c, ["inA":num(Float.nan, "m"), "inB":num(1f, "s")]);    verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["inA":num(Float.posInf, "m"), "inB":num(1f, "s")]); verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["inA":num(-1f), "inB":num(1f)]);     verifyOut(c, -Float.pi / 4f)
      put(c, ["inB":null]);                        verifyOutNull(c)
      put(c, ["inB":num(Float.nan)]);              verifyOut(c, Float.nan)
    }
  }

//////////////////////////////////////////////////////////////////////////
// FlooredModulus
//////////////////////////////////////////////////////////////////////////

  ** The floored remainder has the sign of inB
  Void testModuloSigns()
  {
    run |->|
    {
      // out = inA - floor(inA / inB) * inB, shown as inA - floor * inB
      c := mk("FlooredModulus")
      put(c, ["inA":num(-1f),   "inB":num(3f)]);  verifyOut(c, 2f)    // -1 - (-1)(3)
      put(c, ["inA":num(1f),    "inB":num(-3f)]); verifyOut(c, -2f)   // 1 - (-1)(-3)
      put(c, ["inA":num(-1f),   "inB":num(-3f)]); verifyOut(c, -1f)   // -1 - (0)(-3)
      put(c, ["inA":num(7.5f),  "inB":num(2f)]);  verifyOut(c, 1.5f)  // 7.5 - (3)(2)
      put(c, ["inA":num(-7.5f), "inB":num(2f)]);  verifyOut(c, 0.5f)  // -7.5 - (-4)(2)
      put(c, ["inA":num(7.5f),  "inB":num(-2f)]); verifyOut(c, -0.5f) // 7.5 - (-4)(-2)
      put(c, ["inA":num(-5f),   "inB":num(5f)]);  verifyOut(c, 0f)    // -5 - (-1)(5)
      verify(!outF(c).isNegZero)
      put(c, ["inA":num(5f),    "inB":num(5f)]);  verifyOut(c, 0f)    // 5 - (1)(5)
      put(c, ["inA":num(2f),    "inB":num(7f)]);  verifyOut(c, 2f)    // 2 - (0)(7)
    }
  }

  ** Modulus keeps the truncated remainder and its NaN for a zero divisor
  Void testModulusKeepsTruncatedRemainder()
  {
    run |->|
    {
      // A % B rounds the quotient toward zero, so the remainder has the sign of inA
      c := mk("Modulus")
      put(c, ["inA":num(-1f), "inB":num(3f)]);  verifyOut(c, -1f)        // -1 - (0)(3)
      put(c, ["inA":num(7.5f), "inB":num(-2f)]); verifyOut(c, 1.5f)      // 7.5 - (-3)(-2)
      put(c, ["inA":num(1f), "inB":num(0f)]);   verifyOut(c, Float.nan)  // no remainder of 1/0
    }
  }

  ** A zero inB gives NaN with status ok, as Modulus does
  Void testModuloZeroDivisor()
  {
    run |->|
    {
      c := mk("FlooredModulus")
      put(c, ["inA":num(1f), "inB":num(0f)]);  verifyOut(c, Float.nan)
      put(c, ["inA":num(-1f), "inB":num(3f)]); verifyOut(c, 2f)  // -1 - (-1)(3)
      put(c, ["inB":num(0f)]);                 verifyOut(c, Float.nan)
      put(c, ["inB":num(negZero)]);            verifyOut(c, Float.nan)
      put(c, ["inA":num(0f), "inB":num(0f)]);  verifyOut(c, Float.nan)
      put(c, ["inB":num(0f, null, Status.alarm)]); verifyOut(c, Float.nan, null, Status.alarm)
    }
  }

  ** A NaN the formula gives is in the unit of inA, as Modulus gives 1 m %
  ** 0, and an invalid input gives NaN with no unit
  Void testModuloNaNUnit()
  {
    run |->|
    {
      m := mk("Modulus", ["inA":num(1f, "m"), "inB":num(0f)])
      verifyOut(m, Float.nan, "m")
      c := mk("FlooredModulus", ["inA":num(1f, "m"), "inB":num(0f)])
      verifyOut(c, Float.nan, "m")
      put(c, ["inB":num(0f, "ft")]);                      verifyOut(c, Float.nan, "m")
      put(c, ["inA":num(Float.posInf, "m"), "inB":num(2f)]); verifyOut(c, Float.nan, "m")
      put(c, ["inA":num(1f, "m", Status.down)]);          verifyOut(c, Float.nan, null, Status.down)
    }
  }

  ** out has the unit of inA, inB converts by scale, other units fault
  Void testModuloUnitsFault()
  {
    run |->|
    {
      c := mk("FlooredModulus")
      put(c, ["inA":num(370f, "deg"), "inB":num(360f)]);        verifyOut(c, 10f, "deg")
      put(c, ["inA":num(-10f, "deg"), "inB":num(360f, "deg")]); verifyOut(c, 350f, "deg")
      put(c, ["inA":num(5f, "ft"), "inB":num(0.6096f, "m")]);   verifyOut(c, 1f, "ft", Status.ok, 1e-9f)
      put(c, ["inA":num(70f, "°F"), "inB":num(10f, "Δ°F")]);    verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["inA":num(70f, "m"), "inB":num(10f, "s")]);       verifyOut(c, Float.nan, null, Status.fault)
      put(c, ["inA":num(70f, "m", Status.down)]);               verifyOut(c, Float.nan, null, Status.down)
    }
  }

  ** Null, invalid, NaN and infinite inputs, and the infinite result of an
  ** overflow
  Void testModuloNullInvalid()
  {
    run |->|
    {
      c := mk("FlooredModulus")
      put(c, ["inA":num(-1f, null, Status.down), "inB":num(3f)]);      verifyOut(c, Float.nan, null, Status.down)
      put(c, ["inA":num(-1f), "inB":num(3f)]);                         verifyOut(c, 2f)
      put(c, ["inA":num(4f, null, Status.disabled)]);                  verifyOut(c, Float.nan, null, Status.disabled)
      put(c, ["inB":num(3f, null, Status.stale)])
      verifyOut(c, Float.nan, null, Status.disabled.merge(Status.stale))
      put(c, ["inA":num(4f, null, Status.overridden), "inB":num(3f)]); verifyOut(c, 1f, null, Status.overridden)
      // an infinite input gives NaN: inf - inf, or 0 * inf
      put(c, ["inA":num(Float.posInf)]);                               verifyOut(c, Float.nan)
      put(c, ["inA":num(Float.negInf)]);                               verifyOut(c, Float.nan)
      put(c, ["inA":num(3f), "inB":num(Float.posInf)]);                verifyOut(c, Float.nan)
      put(c, ["inA":num(-3f)]);                                        verifyOut(c, Float.nan)
      // 1 / 1e-310 overflows, so out is 1 - inf, and -1 + inf
      put(c, ["inA":num(1f), "inB":num(1e-310f)]);                     verifyOut(c, Float.negInf)
      put(c, ["inA":num(-1f)]);                                        verifyOut(c, Float.posInf)
      put(c, ["inA":null]);                                            verifyOutNull(c)
    }
  }
}
