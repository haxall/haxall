//
// Copyright (c) 2013, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jun 13  Brian Frank  Creation
//

using xeto
using haystack
using hxConn

**
** EnergyStarUtil
**
const class EnergyStarUtil
{

//////////////////////////////////////////////////////////////////////////
// Unit Mapping
//////////////////////////////////////////////////////////////////////////

  static Str unitToXml(Unit? unit)
  {
    unitToXmlMap[unit] ?: throw ArgErr("Unmapped unit: $unit.name")
  }

  static Unit unitFromXml(Str unit)
  {
    unitFromXmlMap[unit] ?: throw ArgErr("Unmapped unit: $unit")
  }

  private static const Unit:Str unitToXmlMap
  static
  {
    acc := Unit:Str[:]
    try
    {
      acc[Unit("square_foot")]            = "Square Feet"
      acc[Unit("square_meter")]           = "Square Meters"
      acc[Unit("hundred_cubic_feet_natural_gas")] = "ccf (hundred cubic feet)"
      acc[Unit("cubic_foot")]             = "cf (cubic feet)"
      acc[Unit("cubic_feet_natural_gas")] = "cf (cubic feet)"
      //acc[Unit("?")]                    = "Cubic Meters per Day"
      acc[Unit("cubic_meter")]            = "cm (Cubic meters)"
      //acc[Unit("?")]                    = "Cords"
      acc[Unit("imperial_gallon")]        = "Gallons (UK)"
      acc[Unit("gallon")]                 = "Gallons (US)"
      acc[Unit("gigajoule")]              = "GJ"
      acc[Unit("kilobtu")]                = "kBtu (thousand Btu)"
      acc[Unit("thousand_cubic_feet_natural_gas")] = "kcf (thousand cubic feet)"
      //acc[Unit("?")]                    = "Kcm (Thousand Cubic meters)"
      // acc[Unit("?")]                   = "KGal (thousand gallons) (UK)"
      acc[Unit("kgal")]                   = "KGal (thousand gallons) (US)"
      acc[Unit("kilogram")]               = "Kilogram"
      acc[Unit("klb")]                    = "KLbs. (thousand pounds)"
      acc[Unit("kilowatt_hour")]          = "kWh (thousand Watt-hours)"
      acc[Unit("liter")]                  = "Liters"
      acc[Unit("megabtu")]                = "MBtu (million Btu)"
      acc[Unit("million_cubic_feet_natural_gas")]  = "MCF(million cubic feet)"
      //acc[Unit("?")]                    = "mg/l (milligrams per liter)"
      //acc[Unit("?")]                    = "MGal (million gallons) (UK)"
      //acc[Unit("?")]                    = "MGal (million gallons) (US)"
      //acc[Unit("?")]                    = "Million Gallons per Day"
      //acc[Unit("?")]                    = "MLbs. (million pounds)"
      acc[Unit("megawatt_hour")]          = "MWh (million Watt-hours)"
      acc[Unit("pound")]                  = "pounds"
      //acc[Unit("?")]                    = "Pounds per year"
      acc[Unit("therm")]                  = "therms"
      acc[Unit("tonrefh")]                = "ton hours"
      acc[Unit("metric_ton")]             = "Tonnes (metric)"
      acc[Unit("short_ton")]              = "tons"
    }
    catch (Err e) e.trace

    klbs := Unit.fromStr("KLbs", false)
    if (klbs != null) acc[klbs] = "KLbs. (thousand pounds)"

    unitToXmlMap = acc
  }

  private static const Str:Unit unitFromXmlMap
  static
  {
    acc := Str:Unit[:]
    unitToXmlMap.each |v, k| { acc[v] = k }
    unitFromXmlMap = acc
  }

  static Void main()
  {
    unitToXmlMap.each |xml, unit| { echo("$unit.name = $xml") }
  }

//////////////////////////////////////////////////////////////////////////
// Misc
//////////////////////////////////////////////////////////////////////////

  static Str pointToMeterType(Dict pt)
  {
    type := pt["energyStarMeterType"] as Str
    if (type != null) return type
    if (pt["unit"] == "kWh") return "Electric"
    throw Err("Meter point must define energyStarMeterType tag")
  }

  static AssocType meterTypeToAssocType(Str? meterType)
  {
    if (meterType == null) return AssocType.energy
    else if (meterType.contains("Water") && !meterType.contains("District"))
    {
      return AssocType.water
    }
    else if (meterType.startsWith("Composted") || meterType.startsWith("Disposed") ||
             meterType.startsWith("Donated/Reused") || meterType.startsWith("Recycled"))
    {
      return AssocType.waste
    }
    else return AssocType.energy
  }

  static Int toOccupancyPercentage(Number? n)
  {
    // if null assume 100%, only multiples of 5 supported
    if (n == null) return 100
    return n.toInt / 5 * 5
  }

}

enum class AssocType
{
  energy,
  water,
  waste
}

