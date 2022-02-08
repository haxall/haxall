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
  new make(EcobeeDispatch dispatch, ConnPoint point, ConnWriteInfo event)
    : super(dispatch)
  {
    this.point = point
    this.event = event
  }

  private const ConnPoint point
  private const ConnWriteInfo event

  override Obj? run()
  {
    try
    {
      propId := toWriteId(point)
      log.debug("onWrite: $point $propId $event")
      if (!propId.isSettings) throw FaultErr("Only settings properties may be written: $propId")

      selection := EcobeeSelection {
        it.selectionType  = SelectionType.thermostats
        it.selectionMatch = propId.thermostatId
      }
      thermostat := EcobeeThermostat {
        it.settings = toSettings(propId)
      }

      client.thermostat.update(selection, thermostat)
      point.updateWriteOk(event)
    }
    catch (Err err)
    {
      point.updateWriteErr(event, err)
    }
    return null
  }

  private EcobeeSettings toSettings(EcobeePropId propId)
  {
    setter := Field:Obj?[:]
    type   := EcobeeSettings#
    field  := type.field(propId.propSpecs[1].prop)
    setter[field] = EcobeeUtil.toEcobee(event.val, field)
    return type.make([Field.makeSetFunc(setter)])
  }
}