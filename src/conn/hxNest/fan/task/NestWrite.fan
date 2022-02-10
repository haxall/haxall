//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Feb 2022  Matthew Giannini  Creation
//

using haystack
using hxConn

internal class NestWrite : NestConnTask
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(NestDispatch dispatch, ConnPoint point, ConnWriteInfo event)
    : super(dispatch)
  {
    this.point = point
    this.event = event
  }

  private const ConnPoint point
  private const ConnWriteInfo event

//////////////////////////////////////////////////////////////////////////
// Conn Task
//////////////////////////////////////////////////////////////////////////

  override Obj? run()
  {
    try
    {
      traitRef := toWriteId(point)
      trait    := traitRef.trait

      Str? command
      Map? params
      switch (trait)
      {
        case "ThermostatMode":
          command = cmd(trait, "SetMode")
          params = ["mode": event.val.toStr]
        case "ThermostatTemperatureSetpoint":
          command = cmd(trait, traitRef.field == "heatCelsius" ? "SetHeat" : "SetCool")
          params = [traitRef.field: toCelsius(event.val)]
        default:
          throw FaultErr("Unsupported trait for write: $traitRef")
      }
      client.devices.exec(traitRef.deviceId, command, params)
      point.updateWriteOk(event)
    }
    catch (Err err)
    {
      point.updateWriteErr(event, err)
    }
    return null
  }

  private static Str cmd(Str trait, Str command)
  {
    "sdm.devices.commands.${trait}.${command}"
  }

  private Float toCelsius(Obj obj)
  {
    if (obj isnot Number) throw FaultErr("Cannot write $obj ($obj.typeof)")
    num  := (Number)obj
    unit := num.unit ?: point.unit
    if (unit == null) throw FaultErr("Cannot write $num - has not unit and point does not have unit tag")
    if (unit == NestUtil.celsius) return num.toFloat
    if (unit == NestUtil.fahr) return NestUtil.fahr.convertTo(num.toFloat, NestUtil.celsius)
    throw FaultErr("Cannot convert $unit to Celsius")
  }
}