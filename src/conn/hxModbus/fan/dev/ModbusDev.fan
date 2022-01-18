//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Dec 2016  Andy Frank  Creation
//  14 Jan 2022  Matthew Giannini Redesign for Haxall
//

using haystack
using hx

**
** ModbusDev models a modbus device.
**
@NoDoc const class ModbusDev
{
  ** It-block constructor.
  new make(|This| f) { f(this) }

  ** Uri for connectvity to this device.
  const Uri uri

  ** Slave address for this device.
  const Int slave

  ** Register map for this device.
  const ModbusRegMap regMap

  ** If 'true' always use 0x10 write-multiple for writeHoldingRegs
  const Bool forceWriteMultiple := false

  ** Timeout for block reads
  const Duration readTimeout

  ** Timeout for register writes
  const Duration writeTimeout

  ** Create a new ModbusDev instance from a ModbusConn rec.
  static new fromConn(HxRuntime rt, Dict rec)
  {
    uri := rec["uri"]
    if (uri == null) throw FaultErr("Missing 'uri' tag")
    if (uri isnot Uri) throw FaultErr("Invalid 'uri' tag - must be an Uri")

    slave := rec["modbusSlave"]
    if (slave == null) throw FaultErr("Missing 'slave' tag")
    if (slave isnot Number) throw FaultErr("Invalid 'slave' tag - must be a Number")

    regUri := rec["modbusRegMapUri"]
    if (regUri == null) throw FaultErr("Missing 'modbusRegMapUri' tag")
    if (regUri isnot Uri) throw FaultErr("Invalid 'modbusRegMapUri' tag - must be an Uri")

    fwm := rec["modbusForceWriteMultiple"] != null

    return ModbusDev
    {
      it.uri    = uri
      it.slave  = slave->toInt
      it.regMap = loadRegMap(rt, regUri)
      it.forceWriteMultiple = fwm
      it.readTimeout  = toDuration(rec, "modbusReadTimeout", 15sec)
      it.writeTimeout = toDuration(rec, "modbusWriteTimeout", 15sec)
    }
  }

  ** Load register map from URI.
  private static ModbusRegMap loadRegMap(HxRuntime rt, Uri uri)
  {
    file := ModbusRegMap.uriToFile(rt, uri)
    if (!file.exists) throw FaultErr("File not found for modbusRegMapUri: $uri")
    return ModbusRegMap.fromFile(file)
  }

  private Duration toDuration(Dict rec, Str tag, Duration def)
  {
    v := rec[tag]
    if (v == null) return def
    try
    {
      return ((Number)v).toDuration
    }
    catch (Err err)
    {
      throw FaultErr("Invalid '$tag' tag - must be Duration", err)
    }
  }
}
