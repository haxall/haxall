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
** The base spec for the moist air components, which compute from a dry
** bulb temperature and a relative humidity.  `inDryBulb` is in kelvin when
** it has no unit, and K, °C and °F convert.  `inRelHumidity` is a fraction
** when it has no unit, and `%` and `%RH` convert.  After conversion the
** humidity must be from 0 to 1.05 and the dry bulb from -100 °C to 100 °C.
** A null input sets `out` to null, and an invalid input sets it to NaN with
** the merged status.  Any other unit gives NaN with fault.  A NaN, infinite
** or out of range input, and a NaN result, give NaN with no fault, in the
** unit `out` would have.  NaN for an invalid input or with fault has no
** unit.
**
** The relative humidity is relative to liquid water at every temperature,
** as building humidity sensors report it and as the WMO defines it: the
** water vapor pressure is p_w = phi p_ws, with p_ws the saturation pressure
** over liquid water.  p_ws is equation 5 of the 2025 ASHRAE Handbook
** Fundamentals, chapter 1, the IAPWS-IF97 saturation pressure (IAPWS
** R7-97(2012), equation 30), which ASHRAE gives from 0 °C.  Below 0 °C it
** is extrapolated over supercooled water, and `out` still computes with
** status ok.  Against the supercooled water curve of Murphy and Koop
** (2005) it is below by 0.005 % at -10 °C and 0.05 % at -30 °C, and above
** by 0.24 % at -40 °C, 1.5 % at -50 °C and 4.9 % at -60 °C.  Below -60 °C
** the bias grows fast, to 29 % at -80 °C and 265 % at -100 °C.
**
** Below 0 °C this departs from ASHRAE's chapter 1, which takes p_ws over
** ice there (equation 6, the IAPWS R14-08(2011) sublimation pressure),
** and from MBL (the Modelica Buildings Library), which also takes p_ws
** over ice below 0 °C, blending ice and liquid within 1 K of it.  WetBulb
** takes no p_ws, and the departure does not apply to it.
**
@Gen
abstract class Psychrometric : Math
{
  ** The dry bulb temperature, CDL `TDryBul`
  @Gen virtual StatusNumber? inDryBulb() { get("inDryBulb") }

  ** The relative humidity, CDL `phi`
  @Gen virtual StatusNumber? inRelHumidity() { get("inRelHumidity") }

  override Void onExecute()
  {
    t := inDryBulb
    h := inRelHumidity
    if (t == null || h == null) return set("out", null)

    status := t.status.merge(h.status)
    if (!status.isValid) return MathRules.nan(this, status)

    tu := t.num.unit
    hu := h.num.unit
    if (!isTempUnit(tu) || !isHumidityUnit(hu) || isConfigFault)
      return MathRules.fault(this, status)

    // the CDL inputs: TDryBul in K and phi as a fraction.  A NaN or
    // infinite input is out of range.
    tv := t.num.toFloat
    hv := h.num.toFloat
    tK  := tu == null ? tv : tu.convertTo(tv, kelvin)
    phi := hu == null ? hv : hv / 100f
    if (!(phi >= 0f && phi <= maxPhi) || !(tK >= minTK - tolK && tK <= maxTK + tolK))
      return MathRules.nan(this, status, toOut(0f, tu).unit)

    // a result below the CDL output minimum faults; NaN is not below it
    r := compute(tK, phi)
    if (r < minOut) return MathRules.fault(this, status)
    if (r.isNaN) return MathRules.nan(this, status, toOut(0f, tu).unit)

    set("out", StatusNumber(toOut(r, tu), status))
  }

  ** The ASHRAE equations, or Stull's for WetBulb: out in SI from TDryBul
  ** in K and phi from 0 to 1
  protected abstract Float compute(Float tK, Float phi)

  ** The CDL min of the output in SI
  protected virtual Float minOut() { Float.negInf }

  ** The output in SI as a Number, given the unit of inDryBulb
  protected abstract Number toOut(Float r, Unit? tu)

  ** A configuration fault beyond the inputs
  protected virtual Bool isConfigFault() { false }

  ** None, or an absolute temperature: K, °C or °F
  private static Bool isTempUnit(Unit? u)
  {
    u == null || (u.dim == kelvin.dim && !MathRules.isDelta(u))
  }

  ** None, `%` or `%RH`
  private static Bool isHumidityUnit(Unit? u)
  {
    u == null || u == percent || u == percentRh
  }

  ** A temperature in K converted to the unit of inDryBulb
  internal static Number tempOut(Float rK, Unit? tu)
  {
    tu == null ? Number(rK) : Number(kelvin.convertTo(rK, tu), tu)
  }

  ** The saturation pressure of water vapor over liquid water in Pa at `tK`
  ** kelvin, at every temperature: IAPWS-IF97 equation 30, ASHRAE equation
  ** 5, p_ws = 1E6 (2C / (-B + (B^2 - 4AC)^0.5))^4 with A, B and C
  ** quadratics in theta = T + n9 / (T - n10), given from 273.15 K and
  ** extrapolated below it
  static Float saturationPressure(Float tK)
  {
    th := tK + n9 / (tK - n10)
    a := (th + n1) * th + n2
    b := (n3 * th + n4) * th + n5
    c := (n6 * th + n7) * th + n8
    return 1E6f * (2f * c / (-b + (b * b - 4f * a * c).sqrt)).pow(4f)
  }

  ** The coefficients n1 to n10 of IAPWS-IF97 equations 29 to 31, from
  ** Table 34 of IAPWS R7-97(2012)
  internal static const Float n1  :=  0.11670521452767E4f
  internal static const Float n2  := -0.72421316703206E6f
  internal static const Float n3  := -0.17073846940092E2f
  internal static const Float n4  :=  0.12020824702470E5f
  internal static const Float n5  := -0.32325550322333E7f
  internal static const Float n6  :=  0.14915108613530E2f
  internal static const Float n7  := -0.48232657361591E4f
  internal static const Float n8  :=  0.40511340542057E6f
  internal static const Float n9  := -0.23855557567849f
  internal static const Float n10 :=  0.65017534844798E3f

  ** The input bounds, after unit conversion
  private static const Float maxPhi := 1.05f
  private static const Float minTK  := 173.15f
  private static const Float maxTK  := 373.15f

  ** A bound given in °C or °F converts to one float step off its K
  ** value, so the bounds are compared within 1E-9 K
  private static const Float tolK   := 1E-9f

  internal static const Unit kelvin    := Unit("K")
  internal static const Unit percent   := Unit("%")
  internal static const Unit percentRh := Unit("%RH")
}

**
** Computes the dew point temperature of moist air.  It has the interface
** of the CDL `Psychrometrics.DewPoint_TDryBulPhi` block, and computes with
** the 2025 ASHRAE Handbook Fundamentals, chapter 1.  From a p_w of
** 611.657 Pa, the triple point, `out` is the dew point over liquid water
** of equation 39, the IAPWS-IF97 saturation temperature (IAPWS
** R7-97(2012), equation 31).  Below it `out` is the frost point over ice,
** where the sublimation pressure of equation 6 (IAPWS R14-08(2011))
** equals p_w, found by Newton's method on ln p_w to within 1E-9 K.  Both
** give 273.16 K at the triple point.  ASHRAE switches at a dew point of
** 0 °C instead.  The two differ by at most 1.2E-3 K there.  `out` is in
** the unit of `inDryBulb`, kelvin when it has none, a NaN included, but NaN
** for an invalid input or with fault has no unit.  Below 0 °C, with the
** humidity relative to liquid water and `out` a frost point, `out` can be
** above `inDryBulb` at a high humidity: by 2.0 K at -20 °C and by 3.5 K at
** -40 °C, at 100 %.
**
** There is no top limit.  A dew point below 100 K, the output minimum of
** the CDL block, gives NaN with fault.  That covers a relative humidity of
** 0 and the 50 K end of IAPWS equation 6.  A frost point the solver does
** not find gives NaN.  Every other input in range computes, as for the air
** from a desiccant dryer: at 20 °C and 0.5 %, `out` is -40.8 °C.
**
** Departing from MBL (the Modelica Buildings Library), which takes one
** fit over liquid water at every dew point, a p_w below the triple point
** gives the frost point over ice.
**
@Gen
class DewPoint : Psychrometric
{

  ** IAPWS-IF97 equation 31 from a p_w = phi p_ws of 611.657 Pa, and the
  ** frost point of IAPWS R14-08 equation 6 below it, in K.  0, below the
  ** 100 K minimum, below the sublimation pressure at 50 K, where equation
  ** 6 ends, and NaN when the frost point is not found.
  protected override Float compute(Float tK, Float phi)
  {
    pw := phi * saturationPressure(tK)
    if (pw >= triplePa) return saturationTemperature(pw)
    if (!(pw >= minPw)) return 0f
    return frostPoint(pw)
  }

  ** CDL TDewPoi min = 100
  protected override Float minOut() { 100f }

  protected override Number toOut(Float r, Unit? tu) { tempOut(r, tu) }

  ** The saturation temperature over liquid water in K at `pw` Pa: IAPWS-IF97
  ** equation 31, ASHRAE equation 39, with E, F and G quadratics in beta =
  ** (pw / 1E6)^0.25
  internal static Float saturationTemperature(Float pw)
  {
    be := (pw / 1E6f).pow(0.25f)
    e := (be + n3) * be + n6
    f := (n1 * be + n4) * be + n7
    g := (n2 * be + n5) * be + n8
    d := 2f * g / (-f - (f * f - 4f * e * g).sqrt)
    return (n10 + d - ((n10 + d) * (n10 + d) - 4f * (n9 + n10 * d)).sqrt) / 2f
  }

  ** The sublimation pressure of ice in Pa at `tK` kelvin: IAPWS R14-08
  ** equation 6, ln (p / pt) = (a1 theta^b1 + a2 theta^b2 + a3 theta^b3) /
  ** theta with theta = T / Tt, ASHRAE equation 6
  internal static Float sublimationPressure(Float tK)
  {
    th := tK / tripleK
    return triplePa * ((a1 * th.pow(b1) + a2 * th.pow(b2) + a3 * th.pow(b3)) / th).exp
  }

  ** The frost point in K at `pw` Pa, below the triple point: the root of
  ** equation 6 by Newton's method on ln p in x = Tt / T, where ln (p / pt)
  ** = a1 x^(1-b1) + a2 x^(1-b2) + a3 x^(1-b3), from x = 1.  It stops when
  ** a step moves T by at most 1E-9 K, and gives NaN after `maxSteps`
  ** without that.
  internal static Float frostPoint(Float pw, Int maxSteps := 50)
  {
    y := (pw / triplePa).log
    x := 1f
    for (i := 0; i < maxSteps; ++i)
    {
      f  := a1 * x.pow(1f - b1) + a2 * x.pow(1f - b2) + a3 * x.pow(1f - b3) - y
      df := a1 * (1f - b1) * x.pow(-b1) + a2 * (1f - b2) * x.pow(-b2) + a3 * (1f - b3) * x.pow(-b3)
      xn := x - f / df
      if ((tripleK / xn - tripleK / x).abs <= tolT) return tripleK / xn
      x = xn
    }
    return Float.nan
  }

  ** The triple point of IAPWS R7-97 equation 9 and R14-08, in K and Pa
  private static const Float tripleK  := 273.16f
  private static const Float triplePa := 611.657f

  ** The coefficients and exponents of IAPWS R14-08 equation 6
  private static const Float a1 := -0.212144006E2f
  private static const Float a2 :=  0.273203819E2f
  private static const Float a3 := -0.610598130E1f
  private static const Float b1 :=  0.333333333E-2f
  private static const Float b2 :=  0.120666667E1f
  private static const Float b3 :=  0.170333333E1f

  ** The lowest p_w, the sublimation pressure at 50 K, where R14-08 ends
  ** equation 6
  private static const Float minPw := sublimationPressure(50f)

  ** The frost point tolerance in K
  private static const Float tolT := 1E-9f
}

**
** Computes the specific enthalpy of moist air, per kilogram of dry air,
** 0 for dry air at 0 °C.  It has the interface of the CDL
** `Psychrometrics.SpecificEnthalpy_TDryBulPhi` block, and computes with the
** 2025 ASHRAE Handbook Fundamentals, chapter 1, equation 32, with the
** humidity ratio of equation 21.  Kuehn et al. (1998), as chapter 1 cites
** in its introduction, put the error of these perfect gas relations
** under 0.7 % for saturated air at standard atmospheric pressure from
** -50 °C to 50 °C.  Outside that range `out` still computes with status
** ok.  `out` is in J/kg, with the unit `J/kg` when `inDryBulb` has a unit
** and none when it has none, a NaN included, but NaN for an invalid input
** or with fault has no unit.
**
** ASHRAE's chapter 1 and MBL take p_ws over ice below 0 °C, and MBL
** blends ice and liquid within 1 K of it.  Here p_w is over liquid water
** at every temperature, so below 0 °C `out` is higher than with p_ws over
** ice, by 247 J/kg at -5 °C and 80 %.
**
@Gen
class SpecificEnthalpy : Psychrometric
{
  ** The atmospheric pressure, CDL `pAtm`, in Pa when it has no unit, and a
  ** pressure unit converts.  One that is not a pressure, not finite or not
  ** above 0 gives NaN with fault, and one not above the water vapor
  ** pressure gives NaN.
  @Gen virtual Number pAtm { get {get("pAtm")} set {set("pAtm", it)} }

  ** ASHRAE equation 32, h = 1.006 t + W (2501 + 1.86 t) in kJ/kg, here in
  ** J/kg, with the humidity ratio of equation 21, W = 0.621945 p_w /
  ** (p - p_w), and p_w = phi p_ws.  A pAtm not above p_w has no humidity
  ** ratio and gives NaN.
  protected override Float compute(Float tK, Float phi)
  {
    p := pAtmPa
    tC := tK - 273.15f
    pw := phi * saturationPressure(tK)
    if (!(p > pw)) return Float.nan
    w := 0.621945f * pw / (p - pw)
    return 1006f * tC + w * (2501000f + 1860f * tC)
  }

  protected override Number toOut(Float r, Unit? tu)
  {
    Number(r, tu == null ? null : joulesPerKg)
  }

  ** pAtm not finite, not above 0, or not a pressure
  protected override Bool isConfigFault()
  {
    p := pAtmPa
    return p == null || !MathRules.finite(p) || !(p > 0f)
  }

  ** pAtm in Pa, or null when its unit is not a pressure
  private Float? pAtmPa()
  {
    n := pAtm
    u := n.unit
    if (u == null) return n.toFloat
    if (u.dim != pascal.dim || u.offset != 0f) return null
    return u.convertTo(n.toFloat, pascal)
  }

  private static const Unit pascal      := Unit("Pa")
  private static const Unit joulesPerKg := Unit("J/kg")
}

**
** Computes the wet bulb temperature of moist air.  It has the interface of
** the CDL `Psychrometrics.WetBulb_TDryBulPhi` block, and computes with the
** approximation of Stull (2011), equation 1, which is for a relative
** humidity from 5 % to 99 % and a dry bulb from -20 °C to 50 °C at standard
** sea level pressure, within -1 K to +0.65 K.  Outside that range, and at
** low humidity with a cold dry bulb, `out` still computes with status ok
** and can be far off.  `out` is in the unit of `inDryBulb`, kelvin when it
** has none, a NaN included, but NaN for an invalid input or with fault has
** no unit.  Over the input range `out` stays above 165 K, so it does not
** reach 100 K, the output minimum of the CDL block.
**
@Gen
class WetBulb : Psychrometric
{

  ** Stull (2011), equation 1, with T in °C and RH = 100 phi in percent
  protected override Float compute(Float tK, Float phi)
  {
    tC := tK - 273.15f
    rh := 100f * phi
    return 273.15f
      + tC * (0.151977f * (rh + 8.313659f).sqrt).atan
      + ((tC + rh).atan - (rh - 1.676331f).atan + 0.00391838f * rh.pow(1.5f) * (0.023101f * rh).atan)
      - 4.686035f
  }

  ** CDL TWetBul min = 100
  protected override Float minOut() { 100f }

  protected override Number toOut(Float r, Unit? tu) { tempOut(r, tu) }
}
