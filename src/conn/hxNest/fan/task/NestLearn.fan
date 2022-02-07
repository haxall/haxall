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

  private Dict[] learnThermostat(Dict arg, NestThermostat t)
  {
    points := Dict[,]

    points.add(PointBuilder(t).dis("Humidity").kind("Number").unit(celsius)
      .cur("Humidity.ambientHumidityPercent").markers("zone,air,humidity,sensor").finish)

    points.add(PointBuilder(t).dis("Temp").kind("Number").unit(celsius)
      .cur("Temperature.ambientTemperatureCelsius").markers("zone,air,temp,sensor").finish)

    // TODO: not sure how to tag this
    points.add(PointBuilder(t).dis("Thermostat Mode").kind("Str").enums("HEAT,COOL,HEATCOOL,OFF")
      .cur("ThermostatMode.mode").finish)
    points.add(PointBuilder(t).dis("Thermostat Status").kind("Str").enums("OFF,HEATING,COOLING")
      .cur("ThermostatHvac.status").markers("zone,air,hvacMode,sensor").finish)

    points.add(PointBuilder(t).dis("Heating Setpoint").kind("Number").unit(celsius)
      .cur("ThermostatTemperatureSetpoint.heatCelsius").markers("zone,air,temp,heating,sp").finish)
    points.add(PointBuilder(t).dis("Cooling Setpoint").kind("Number").unit(celsius)
      .cur("ThermostatTemperatureSetpoint.coolCelsius").markers("zone,air,temp,heating,sp").finish)

    return points
  }
}

**************************************************************************
** PointBuilder
**************************************************************************

internal class PointBuilder
{
  new make(NestDevice device)
  {
    this.device = device
    this.tags = Str:Obj?[
      "point": Marker.val,
      "nestPoint": Marker.val,
    ]
  }

  private NestDevice device
  private Str:Obj tags

  private This set(Str tag, Obj? val) { tags[tag] = val; return this }

  This dis(Str dis) { set("dis", dis) }
  This kind(Str kind) { set("kind", kind) }
  This unit(Unit unit) { set("unit", unit.toStr) }
  This cur(Str trait) { set("nestCur", "${device.id}:${trait}") }
  This enums(Str enums) { set("enum", enums) }
  This markers(Str markers)
  {
    markers.split(',').each |marker| { tags[marker] = Marker.val }
    return this
  }

  Dict finish() { Etc.makeDict(tags) }
}