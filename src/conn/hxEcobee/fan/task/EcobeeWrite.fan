//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Feb 2022  Matthew Giannini  Creation
//

using haystack
using hxConn

internal class EcobeeWrite : EcobeeConnTask
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(EcobeeDispatch dispatch, ConnPoint point, ConnWriteInfo event)
    : super(dispatch)
  {
    this.point = point
    this.event = event
  }

  private const ConnPoint point
  private const ConnWriteInfo event

  private EcobeePropId? propId
  private EcobeeSelection? selection

//////////////////////////////////////////////////////////////////////////
// Conn Task
//////////////////////////////////////////////////////////////////////////

  override Obj? run()
  {
    try
    {
      this.propId = toWriteId(point)
      log.debug("onWrite: $point $propId $event")

      this.selection = EcobeeSelection {
        it.selectionType  = SelectionType.thermostats
        it.selectionMatch = propId.thermostatId
      }

      if (propId.isSettings) writeSettings
      else invokeFunc

      point.updateWriteOk(event)
    }
    catch (Err err)
    {
      point.updateWriteErr(event, err)
    }
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Write Settings
//////////////////////////////////////////////////////////////////////////

  private Void writeSettings()
  {
    thermostat := EcobeeThermostat {
      it.settings = toSettings(propId)
    }
    client.thermostat.update(selection, thermostat)
  }

  private EcobeeSettings toSettings(EcobeePropId propId)
  {
    setter := Field:Obj?[:]
    type   := EcobeeSettings#
    field  := type.field(propId.propSpecs[1].prop)
    setter[field] = EcobeeUtil.toEcobee(event.val, field)
    return type.make([Field.makeSetFunc(setter)])
  }

//////////////////////////////////////////////////////////////////////////
// Invoke Function
//////////////////////////////////////////////////////////////////////////

  private Void invokeFunc()
  {
    if (propId.propUri == `runtime/desiredHeat` || propId.propUri == `runtime/desiredCool`)
    {
      func := EcobeeFunction("setHold", [
        "holdType":     "indefinite",
        "heatHoldTemp": ((Number)event.val).toInt,
        "coolHoldTemp": ((Number)event.val).toInt,
      ])
      client.thermostat.callFunc(selection, func)
    }
    else
    {
      throw FaultErr("Property not supported for write: $propId")
    }
  }
}