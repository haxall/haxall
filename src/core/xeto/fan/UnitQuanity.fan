//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Nov 2024  Brian Frank  Creation
//

using util

**
** UnitQuantity models the sys::UnitQuanity Xeto enum in Fantom
**
@NoDoc @Js
enum class UnitQuantity
{
  dimensionless,
  currency,
  acceleration,
  angularAcceleration,
  angularMomentum,
  angularVelocity,
  area,
  capacitance,
  coolingEfficiency,
  density,
  electricCharge,
  electricConductance,
  electricCurrent,
  electromagneticMoment,
  electricCurrentDensity,
  electricFieldStrength,
  electricPotential,
  electricResistance,
  electricalConductivity,
  electricalResistivity,
  energy,
  apparentEnergy,
  reactiveEnergy,
  energyByArea,
  energyByVolume,
  enthalpy,
  entropy,
  force,
  frequency,
  grammage,
  heatingRate,
  illuminance,
  inductance,
  irradiance,
  length,
  luminance,
  luminousFlux,
  luminousIntensity,
  magneticFieldStrength,
  magneticFlux,
  magneticFluxDensity,
  mass,
  massFlow,
  momentum,
  power,
  powerByArea,
  powerByVolumetricFlow,
  apparentPower,
  reactivePower,
  pressure,
  specificEntropy,
  surfaceTension,
  temperature,
  temperatureDifferential,
  thermalConductivity,
  time,
  velocity,
  volume,
  volumetricFlow,
  bytes


  ** Map of Unit -> UnitQuantity
  @NoDoc once static Unit:UnitQuantity unitToQuantity()
  {
    acc := Unit:UnitQuantity[:]
    Unit.quantities.each |qn|
    {
      q := fromStr(qn.fromDisplayName, false)
      if (q == null)
        echo("WARN: UnitQuantity not mapped by enum: $qn")
      else
        Unit.quantity(qn).each |u| { acc[u] = q }
    }
    return acc.toImmutable
  }
}

