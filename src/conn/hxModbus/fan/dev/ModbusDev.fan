//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Dec 2016  Andy Frank       Creation
//  14 Jan 2022  Matthew Giannini Redesign for Haxall
//

using xeto
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

  ** Register map for this device, or null if every point addresses its
  ** registers directly by addr spec.
  const ModbusRegMap? regMap

  ** Project used to resolve addr specs.
  const Proj proj

  ** Qname of the spec which models this device, or null.
  const Str? deviceSpec

  ** Name of the point to read for ping, resolved within `deviceSpec`,
  ** or null to fall back to the 'ping' register in the map.
  const Str? pingId

  ** If `true` always use 0x10 write-multiple for writeHoldingRegs
  const Bool forceWriteMultiple := false

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

    // optional: points may address their registers by spec instead. The
    // conn template seeds an empty uri, so treat that as unset.
    regUri := rec["modbusRegMapUri"]
    if (regUri != null && regUri isnot Uri) throw FaultErr("Invalid 'modbusRegMapUri' tag - must be an Uri")
    if (regUri == ``) regUri = null

    pingId := rec["modbusPingAddr"]
    if (pingId != null)
    {
      if (pingId isnot Str) throw FaultErr("Invalid 'modbusPingAddr' tag - must be a Str")
      if (pingId.toStr.contains("::"))
        throw FaultErr("Invalid 'modbusPingAddr' tag - must be a point name such as \"msi2\", not a qname")
    }

    fwm := rec["modbusForceWriteMultiple"] != null

    return ModbusDev
    {
      it.uri    = uri
      it.slave  = slave->toInt
      it.proj   = conn.proj
      it.regMap = regUri == null ? null : loadRegMap(conn.proj, regUri)
      it.pingId = pingId
      it.deviceSpec = rec["modbusDeviceSpec"]
      it.forceWriteMultiple = fwm
      it.frameDelay   = toDuration(rec, "modbusFrameDelay", 0sec, conn.tuning.rec)
      it.readTimeout  = toDuration(rec, "modbusReadTimeout", conn.timeout)
      it.writeTimeout = toDuration(rec, "modbusWriteTimeout", conn.timeout)
      it.timeout = conn.timeout
      it.log = conn.trace.asLog
    }
  }

  ** Resolve a modbusCur/modbusWrite value to its register. A value with a
  ** "::" is the qname of a point spec, and the tag it came from selects
  ** which addr global to read off it; any other value is a register name
  ** in the map.
  ModbusReg reg(Str id, Bool forWrite)
  {
    if (!id.contains("::"))
    {
      if (regMap == null) throw FaultErr("Missing 'modbusRegMapUri' tag")
      return regMap.reg(id)
    }

    checkNamed(id)
    name := forWrite ? "modbusWriteAddr" : "modbusCurAddr"
    spec := resolveSpec(proj.ns, id, forWrite ? "modbusWrite" : "modbusCur")
    addr := spec.slot(name, false) ?: throw FaultErr("Missing ${name}: ${id}")
    return ModbusReg.fromSpec(addr, forWrite)
  }

  ** Resolve a spec named by a tag. A lib which is not enabled in this
  ** project reads the same as a bad qname, so report the two separately.
  internal static Spec resolveSpec(Namespace ns, Str qname, Str tag)
  {
    spec := ns.spec(qname, false)
    if (spec != null) return spec

    colon := qname.index("::")
    if (colon == null) throw FaultErr("Invalid '${tag}' qname: ${qname}")
    lib := qname[0..<colon]
    if (ns.lib(lib, false) == null)
      throw FaultErr("Lib not enabled in this project for '${tag}': ${lib}")
    throw FaultErr("Unknown '${tag}' spec: ${qname}")
  }

  ** An auto-named slot is positional: its index shifts when the spec gains
  ** a constraint, and is renumbered again when a subtype merges inherited
  ** ones, so it cannot identify a register across edits.
  internal static Void checkNamed(Str qname)
  {
    qname.split('.').each |n|
    {
      if (n.size < 2 || n[0] != '_') return
      if (n[1..-1].all |c| { c.isDigit }) throw FaultErr("Point slot must be named, not positional: ${qname}")
    }
  }

  ** Register to read for ping, or null if this device has no way to ping.
  ** A device with a register map defines a register named "ping"; one
  ** modelled by a spec names one of that spec's points, such as "msi2".
  ModbusReg? pingReg()
  {
    if (pingId == null) return regMap?.reg("ping", false)
    if (deviceSpec == null) throw FaultErr("'modbusPingAddr' requires 'modbusDeviceSpec'")

    spec := resolveSpec(proj.ns, deviceSpec, "modbusDeviceSpec")
    pt   := pointIn(spec, pingId) ?: throw FaultErr("Unknown point for 'modbusPingAddr': ${pingId}")
    addr := pt.slot("modbusCurAddr", false) ?: throw FaultErr("Point has no modbusCurAddr for 'modbusPingAddr': ${pingId}")
    return ModbusReg.fromSpec(addr, false)
  }

  ** Find a point of a device spec by slot name
  internal static Spec? pointIn(Spec deviceSpec, Str name)
  {
    deviceSpec.slot("points", false)?.slots?.get(name, false)
  }

  ** Load register map from URI.
  private static ModbusRegMap loadRegMap(Proj rt, Uri uri)
  {
    ModbusRegMap.fromFile(ModbusRegMap.uriToCsv(rt, uri))
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

