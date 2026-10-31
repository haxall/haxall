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
** DewPoint, SpecificEnthalpy and WetBulb, with expected values worked from
** the 2025 ASHRAE Handbook Fundamentals, chapter 1, the IAPWS releases it
** takes its equations from, and Stull (2011).  Temperatures in K unless a
** unit is given.
**
class PsychrometricTest : MathCompTest
{
  static Float pSat(Float tK) { Psychrometric.saturationPressure(tK) }

  ** IAPWS-IF97 equation 30 at every temperature, over supercooled water
  ** below 0 °C too: 611.657 Pa at the triple point, and the release's
  ** check value at 300 K
  Void testSaturationPressure()
  {
    Float:Float cases := [
      173.15f: 0.011131117216681263f,
      233.15f: 18.956764359871372f,
      253.15f: 125.45696448655319f,
      273.15f: 611.2126774443467f,
      293.15f: 2339.2147667769f,
      373.15f: 101417.97792131039f,
    ]
    cases.each |p, t| { verify((pSat(t) - p).abs <= 1e-12f * p, "pSat($t) = ${pSat(t)}, expected $p") }
    verify((pSat(273.16f) - 611.657f).abs < 1e-6f)
    // IAPWS R7-97 Table 35: 3.53658941E-3 MPa at 300 K, within half its last figure
    verify((pSat(300f) - 3536.58941f).abs <= 5e-6f, "pSat(300) = ${pSat(300f)}")
  }

  ** The dew point over liquid water from a vapor pressure at the triple
  ** point, with no top limit, and the same temperature either side of it
  Void testDewPoint()
  {
    run |->|
    {
      // saturated at 20 °C gives the dry bulb, and 50 % gives 9.27 °C
      d := mk("DewPoint", ["inDryBulb":num(293.15f), "inRelHumidity":num(1f)])
      verifyOut(d, 293.15f)
      put(d, ["inRelHumidity":num(0.5f)])
      verifyOut(d, 282.42279996440095f)
      put(d, ["inDryBulb":num(20f, "°C"), "inRelHumidity":num(50f, "%")])
      verifyOut(d, 9.2727999644009635f, "°C", Status.ok, 1e-10f)

      // IAPWS R7-97 Table 36: 372.755919 K at 0.1 MPa, within half its last
      // figure, 5E-7 K
      put(d, ["inDryBulb":num(373.15f), "inRelHumidity":num(100_000f / pSat(373.15f))])
      verifyOut(d, 372.755919f, null, Status.ok, 5e-7f / 372.755919f)
      // saturated at 100 °C, and at 105 %, above the dry bulb
      put(d, ["inRelHumidity":num(1f)]);    verifyOut(d, 373.15f)
      put(d, ["inRelHumidity":num(1.05f)]); verifyOut(d, 374.52297597946244f)

      // 1e-12 above and below 611.657 Pa: the dew point and the frost point
      // both give 273.16 K, within 1E-9 K of each other
      put(d, ["inDryBulb":num(293.15f), "inRelHumidity":num(611.657f * (1f + 1e-12f) / pSat(293.15f))])
      verifyOut(d, 273.15999999977379f)
      above := outF(d)
      put(d, ["inRelHumidity":num(611.657f * (1f - 1e-12f) / pSat(293.15f))])
      verifyOut(d, 273.15999999998786f)
      verify((outF(d) - above).abs < 1e-9f, "${outF(d)} and $above")
      // 611.4 Pa, between 611.213 Pa, where equation 31 gives 0 °C, and the
      // triple point, gets the frost point, not equation 31's 273.15421669901741
      put(d, ["inRelHumidity":num(611.4f / pSat(293.15f))])
      verifyOut(d, 273.1548969193837f)
    }
  }

  ** The frost point over ice below the triple point, down to the 100 K
  ** output minimum, below which it faults, as a humidity of 0 does
  Void testFrostPoint()
  {
    run |->|
    {
      d := mk("DewPoint", ["inDryBulb":num(268.15f), "inRelHumidity":num(0.8f)])
      verifyOut(d, 266.12412089806361f)
      // saturated at -20 °C and -40 °C, 2.0 K and 3.5 K above the dry bulb
      put(d, ["inDryBulb":num(253.15f), "inRelHumidity":num(1f)])
      verifyOut(d, 255.19734321359476f)
      put(d, ["inDryBulb":num(233.15f)])
      verifyOut(d, 236.6437575193531f)

      // a frost point of -80 °C from 20 °C, at the sublimation pressure there
      put(d, ["inDryBulb":num(293.15f), "inRelHumidity":num(0.054772990840093572f / pSat(293.15f))])
      verifyOut(d, 193.15f)
      // IAPWS R14-08 Table 3: 8.94735E-6 MPa at 230 K, within 5E-6 K, where
      // half its last figure, carried to T, is 4.8E-6 K
      put(d, ["inRelHumidity":num(8.94735f / pSat(293.15f))])
      verifyOut(d, 230f, null, Status.ok, 5e-6f / 230f)
      // 20 °C at 0.5 %, as from a desiccant dryer: -40.8 °C
      put(d, ["inRelHumidity":num(0.005f)])
      verifyOut(d, 232.32744195749311f)
      // just above 100 K at -100 °C, then just below it and a humidity of 0
      // give NaN with fault
      put(d, ["inDryBulb":num(173.15f), "inRelHumidity":num(1e-12f)])
      verifyOut(d, 100.04160969863074f)
      put(d, ["inRelHumidity":num(8e-13f)]); verifyOut(d, Float.nan, null, Status.fault)
      put(d, ["inRelHumidity":num(0f)]);     verifyOut(d, Float.nan, null, Status.fault)

      // the solve takes 4 steps at 1e-30 Pa, and gives NaN when held to 3
      verify((DewPoint.frostPoint(1e-30f, 4) - 61.711804045716754f).abs <= 1e-12f * 61.711804045716754f)
      verify(DewPoint.frostPoint(1e-30f, 3).isNaN)
    }
  }

  ** Equation 32 in J/kg with the humidity ratio of equation 21: 1006 J/kg
  ** per K for dry air, 0 at 0 °C, and a vapor term with p_w / (pAtm - p_w)
  Void testSpecificEnthalpy()
  {
    run |->|
    {
      h := mk("SpecificEnthalpy", ["inDryBulb":num(273.15f), "inRelHumidity":num(0f)])
      verifyOut(h, 0f)
      put(h, ["inDryBulb":num(283.15f)]);   verifyOut(h, 10060f, null, Status.ok, 1e-10f)
      put(h, ["inDryBulb":num(50f, "°F")]); verifyOut(h, 10060f, "J/kg", Status.ok, 1e-10f)
      // a pAtm of 2 p_w makes W = 0.621945, and at 0 °C h = 2501000 W
      pw := pSat(273.15f)
      h0 := 0.621945f * 2501000f
      put(h, ["inDryBulb":num(273.15f), "inRelHumidity":num(1f), "pAtm":nu(2f * pw)])
      verifyOut(h, h0)
      put(h, ["pAtm":nu(3f * pw / 1000f, "kPa")]); verifyOut(h, h0 / 2f)
      // a pAtm not above p_w has no humidity ratio, and a pAtm not a pressure,
      // not finite or not above 0 is a fault
      put(h, ["pAtm":nu(pw)]);              verifyOut(h, Float.nan)
      put(h, ["inDryBulb":num(0f, "°C")]);  verifyOut(h, Float.nan, "J/kg")
      put(h, ["pAtm":nu(101325f, "°F")]);   verifyOut(h, Float.nan, null, Status.fault)
      put(h, ["pAtm":nu(Float.posInf)]);    verifyOut(h, Float.nan, null, Status.fault)
      put(h, ["pAtm":nu(0f)]);              verifyOut(h, Float.nan, null, Status.fault)
      // an invalid input gives its status ahead of a pAtm fault
      put(h, ["inDryBulb":num(273.15f, null, Status.down)]); verifyOut(h, Float.nan, null, Status.down)
      // 20 °C and 50 % at 101325 Pa
      put(h, ["inDryBulb":num(293.15f), "inRelHumidity":num(0.5f), "pAtm":nu(101325f)])
      verifyOut(h, 38555.01876278143f)
      // -10 °C and 50 %, with p_w over liquid water below 0 °C too
      put(h, ["inDryBulb":num(263.15f)])
      verifyOut(h, -7874.6486159850529f)
      // -5 °C and 80 %, 247 J/kg above -98.863597548834832, its value with
      // p_ws over ice
      put(h, ["inDryBulb":num(268.15f), "inRelHumidity":num(0.8f)])
      verifyOut(h, 147.68921794996783f)
    }
  }

  ** Stull's equation 1 at 20 °C and 50 %, which his paper works to 13.7 °C
  Void testWetBulb()
  {
    run |->|
    {
      tw := 20f * (0.151977f * (50f + 8.313659f).pow(0.5f)).atan + (20f + 50f).atan - (50f - 1.676331f).atan
        + 0.00391838f * 50f.pow(1.5f) * (0.023101f * 50f).atan - 4.686035f
      verify((tw - 13.7f).abs < 0.05f)
      w := mk("WetBulb", ["inDryBulb":num(293.15f), "inRelHumidity":num(0.5f)])
      verifyOut(w, tw + 273.15f)
      put(w, ["inDryBulb":num(68f, "°F"), "inRelHumidity":num(50f, "%RH")])
      verifyOut(w, tw * 1.8f + 32f, "°F", Status.ok, 1e-10f)
    }
  }

  ** A humidity outside 0 to 1.05 and a dry bulb outside -100 °C to 100 °C
  ** give NaN with status ok, in the unit `out` would have, a unit that does
  ** not fit gives NaN with fault, and the upper bounds compute
  Void testRangesAndUnits()
  {
    run |->|
    {
      [Str:Obj][] range := [
        ["inRelHumidity":num(1.0501f)],
        ["inRelHumidity":num(-0.0001f)],
        ["inRelHumidity":num(50f)],
        ["inRelHumidity":num(0.5f), "inDryBulb":num(100.001f, "°C")],
        ["inDryBulb":num(-100.001f, "°C")],
      ]
      [Str:Obj][] units := [
        ["inRelHumidity":num(0.5f, "rad")],
        ["inRelHumidity":num(0.5f), "inDryBulb":num(293.15f, "ΔK")],
        ["inDryBulb":num(68f, "m")],
      ]
      ["DewPoint":"°C", "SpecificEnthalpy":"J/kg", "WetBulb":"°C"].each |unit, spec|
      {
        c := mk(spec)
        put(c, ["inDryBulb":num(293.15f), "inRelHumidity":num(1.05f)])
        verifyEq((c.get("out") as StatusNumber).status, Status.ok)
        range.each |s|
        {
          put(c, ["inDryBulb":num(100f, "°C"), "inRelHumidity":num(0.5f)])
          verifyEq((c.get("out") as StatusNumber).status, Status.ok)
          put(c, s); verifyOut(c, Float.nan, unit, Status.ok)
        }
        units.each |s|
        {
          put(c, ["inDryBulb":num(100f, "°C"), "inRelHumidity":num(0.5f)])
          put(c, s); verifyOut(c, Float.nan, null, Status.fault)
        }
      }
    }
  }

  ** Units are checked before the range, so a NaN input with a unit that
  ** does not fit faults
  Void testCheckOrder()
  {
    run |->|
    {
      [mk("DewPoint"), mk("SpecificEnthalpy"), mk("WetBulb")].each |c|
      {
        put(c, ["inDryBulb":num(Float.nan, "m"), "inRelHumidity":num(0.5f)]); verifyOut(c, Float.nan, null, Status.fault)
        put(c, ["inDryBulb":num(293.15f), "inRelHumidity":num(Float.nan, "rad")]); verifyOut(c, Float.nan, null, Status.fault)
        put(c, ["inRelHumidity":num(Float.nan)]); verifyOut(c, Float.nan)
      }
    }
  }

  ** Null, invalid and non-finite inputs
  Void testNullInvalid()
  {
    run |->|
    {
      [mk("DewPoint"), mk("SpecificEnthalpy"), mk("WetBulb")].each |c|
      {
        put(c, ["inDryBulb":num(293.15f)]);                      verifyOutNull(c)
        put(c, ["inRelHumidity":num(0.5f, null, Status.stale)]); verifyOut(c, Float.nan, null, Status.stale)
        put(c, ["inRelHumidity":num(Float.nan)]);                verifyOut(c, Float.nan)
        put(c, ["inRelHumidity":num(0.5f)]);                     verifyEq((c.get("out") as StatusNumber).status, Status.ok)
        put(c, ["inDryBulb":num(1f, null, Status.down)]);        verifyOut(c, Float.nan, null, Status.down)
        put(c, ["inDryBulb":num(1f, "m", Status.down)]);         verifyOut(c, Float.nan, null, Status.down)
        put(c, ["inRelHumidity":num(0.5f, null, Status.stale)]); verifyOut(c, Float.nan, null, Status.down.merge(Status.stale))
        put(c, ["inDryBulb":num(Float.posInf), "inRelHumidity":num(0.5f)]); verifyOut(c, Float.nan)
        put(c, ["inDryBulb":null]);                              verifyOutNull(c)
        put(c, ["inDryBulb":num(Float.nan)]);                    verifyOut(c, Float.nan)
      }
    }
  }
}
