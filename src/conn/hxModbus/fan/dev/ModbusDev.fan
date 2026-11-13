//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Dec 2016  Andy Frank       Creation
//  14 Jan 2022  Matthew Giannini Redesign for Haxall
//

using haystack
using hx
using hxConn

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

  ** If 'true' always write coils with 0x0f, even for a single coil
  const Bool forceMultiCoils := false

  ** If 'true' always write holding registers with 0x10, even for a
  ** single register
  const Bool forceMultiRegs := false

  ** Minimum silence to enforce on the wire between transactions
  const Duration frameDelay

  ** Timeout for block reads
  const Duration readTimeout

  ** Timeout for register writes
  const Duration writeTimeout

  ** Default I/O timeout (for socket configuration)
  const Duration timeout

  ** Log for this device
  const Log? log

  ** Create a new ModbusDev instance from a ModbusConn rec.
  static new fromConn(Conn conn)
  {
    rec := conn.rec
    uri := rec["uri"]
    if (uri == null) throw FaultErr("Missing 'uri' tag")
    if (uri isnot Uri) throw FaultErr("Invalid 'uri' tag - must be an Uri")

    slave := rec["modbusSlave"]
    if (slave == null) throw FaultErr("Missing 'slave' tag")
    if (slave isnot Number) throw FaultErr("Invalid 'slave' tag - must be a Number")

    regUri := rec["modbusRegMapUri"]
    if (regUri == null) throw FaultErr("Missing 'modbusRegMapUri' tag")
    if (regUri isnot Uri) throw FaultErr("Invalid 'modbusRegMapUri' tag - must be an Uri")

    return ModbusDev
    {
      it.uri    = uri
      it.slave  = slave->toInt
      it.regMap = loadRegMap(conn.rt, regUri)
      it.forceMultiCoils = rec.has("modbusForceMultiCoils")
      // modbusForceWriteMultiple is the undocumented legacy name
      it.forceMultiRegs  = rec.has("modbusForceMultiRegs") || rec.has("modbusForceWriteMultiple")
      it.frameDelay   = toDuration(rec, "modbusFrameDelay", 0sec, conn.tuning.rec)
      it.readTimeout  = toDuration(rec, "modbusReadTimeout", conn.timeout)
      it.writeTimeout = toDuration(rec, "modbusWriteTimeout", conn.timeout)
      it.timeout = conn.timeout
      it.log = conn.trace.asLog
    }
  }

  ** Load register map from URI.
  private static ModbusRegMap loadRegMap(HxRuntime rt, Uri uri)
  {
    file := ModbusRegMap.uriToFile(rt, uri)
    if (!file.exists) throw FaultErr("File not found for modbusRegMapUri: $uri")
    return ModbusRegMap.fromFile(file)
  }

  ** Resolve duration tag from conn rec, falling back to the conn tuning rec
  private Duration toDuration(Dict rec, Str tag, Duration def, Dict? tuning := null)
  {
    v := rec[tag] ?: tuning?.get(tag)
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
