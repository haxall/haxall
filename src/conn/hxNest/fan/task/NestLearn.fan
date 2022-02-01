//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   01 Feb 2022  Matthew Giannini  Creation
//

using haystack

**
** Learn Nest devices
**
internal class NestLearn : NestConnTask, NestUtil
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(NestDispatch dispatch, Obj? arg) : super(dispatch)
  {
    this.arg = arg
  }

  private Obj? arg

//////////////////////////////////////////////////////////////////////////
// Learn
//////////////////////////////////////////////////////////////////////////

  Grid learn() { run }

  override Obj? run()
  {
    t1 := Duration.now
    try
    {
      openPin
      meta := ["nestConnRef": conn.id]
      rows := Dict[,]
      spec := arg as Dict
      if (arg == null)                rows = learnStructures
      else if (spec.has("structure")) rows = learnRooms(spec)
      else if (spec.has("room"))      rows = learnDevices(spec)
      else if (spec.has("device"))    rows = learnPoints(spec)
      else throw Err("Unexpected arg: ${arg}")
      return Etc.makeDictsGrid(meta, rows)
    }
    finally
    {
      closePin
      t2 := Duration.now
      log.info("${conn.dis} Learn ${arg} [${(t2-t1).toLocale}]")
    }
  }

  private Dict[] learnStructures()
  {
    acc := Dict[,]
    structures := client.structures.list
    structures.each |structure|
    {
      acc.add(Etc.makeDict([
        "learn": Etc.makeDict([
          "structure":   structure.name,
          "structureId": structure.id,
         ]),
        "dis": structure.dis,
      ]))
    }
    return acc
  }

  private Dict[] learnRooms(Dict arg)
  {
    acc := Dict[,]
    rooms := client.rooms.list(arg["structureId"])
    rooms.each |room|
    {
      acc.add(Etc.makeDict([
        "learn": Etc.makeDict(["room": room.name]),
        "dis": room.dis,
      ]))
    }
    return acc
  }

  private Dict[] learnDevices(Dict arg)
  {
    room := arg["room"] as Uri
    acc  := Dict[,]
    devices := client.devices.list
    devices.each |device|
    {
      // only support thermostats right now
      if (device isnot NestThermostat) return

      // skip devides not in this room
      r := device.parentRelations.find { it.parent == room }
      if (r == null) return

      dis := device.dis.trimToNull
      if (dis == null) dis = "${r.dis} ${device.typeName}"

      acc.add(Etc.makeDict([
        "learn": Etc.makeDict(["device": device.name, "deviceId": device.id, "dis": dis]),
        "dis": dis,
      ]))
    }
    return acc
  }

  private Dict[] learnPoints(Dict arg)
  {
    deviceId := arg["deviceId"]
    device := client.devices.get(deviceId)

    if (device is NestThermostat) return learnThermostat(arg, device)
    throw Err("Unsupported device: ${device.type}")
  }

  private Dict[] learnThermostat(Dict arg, NestThermostat device)
  {
    points    := Dict[,]
    points.add(toPoint(device, "Humidity.ambientHumidityPercent", "Humidity", relHum))
    points.add(toPoint(device, "Temperature.ambientTemperatureCelsius", "Temp", celsius))
    points.add(toPoint(device, "ThermostatMode.mode", "Thermostat Mode", null, ["enum":"HEAT,COOL,HEATCOOL,OFF"]))
    points.add(toPoint(device, "ThermostatHvac.status", "Thermostat Status", null, ["enum":"OFF,HEATING,COOLING"]))
    points.add(toPoint(device, "ThermostatTemperatureSetpoint.heatCelsius", "Heating Setpoint", celsius))
    points.add(toPoint(device, "ThermostatTemperatureSetpoint.coolCelsius", "Cooling Setpoint", celsius))
    return points
  }

  private Dict toPoint(NestDevice device, Str trait, Str dis, Unit? unit := null, Str:Obj? tags := [:])
  {
    tags["point"]     = Marker.val
    tags["nestPoint"] = Marker.val
    tags["nestCur"]   = "${device.id}:${trait}"
    tags["dis"]       = dis
    tags["unit"]      = unit?.toStr

    if (tags["kind"] == null)
      tags["kind"] = unit == null ? "Str" : "Number"

    return Etc.makeDict(tags)
  }
}