//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2022  Matthew Giannini  Creation
//

using haystack

**
** Nest Thermostat Device
**
const class NestThermostat : NestDevice
{
  new make(Map json) : super(json)
  {
  }

  Connectivity connectivity()
  {
    Connectivity.fromStr(traitVal("Connectivity", "status"))
  }

  Bool isFanOn()
  {
    traitVal("Fan", "timerMode") == "ON"
  }

  Float humidity()
  {
    traitVal("Humidity", "ambientHumidityPercent")
  }

  Float temperature()
  {
    traitVal("Temperature", "ambientTemperatureCelsius")
  }

  HvacStatus status()
  {
    HvacStatus.fromStr(traitVal("ThermostatHvac", "status"))
  }

  ThermostatMode mode()
  {
    ThermostatMode.fromStr(traitVal("ThermostatMode", "mode"))
  }

  Str:Float setpoint()
  {
    Str:Float[
      "heatCelsius": traitVal("ThermostatTemperatureSetpoint", "heatCelsius"),
      "coolCelsius": traitVal("ThermostatTemperatureSetpoint", "coolCelsius"),
    ]
  }
}

**************************************************************************
** Connectivity
**************************************************************************

enum class Connectivity
{
  ONLINE, OFFLINE

  Bool isOnline() { this === Connectivity.ONLINE }
}

**************************************************************************
** ThermostatMode
**************************************************************************

enum class ThermostatMode
{
  HEAT, COOL, HEATCOOL, OFF
}

**************************************************************************
** HvacStatus
**************************************************************************

enum class HvacStatus
{
  OFF, HEATING, COOLING
}