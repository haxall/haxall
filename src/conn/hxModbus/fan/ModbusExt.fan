//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    9 Jul 2012  Andy Frank        Creation
//   12 Jan 2022  Matthew Giannini  Redesign for Haxall
//

using concurrent
using xeto
using haystack
using hx
using hxConn

**
** Modbus connector library
**
const class ModbusExt : ConnExt
{
  static ModbusExt? cur(Bool checked := true)
  {
    Context.cur.ext("hx.modbus", checked)
  }

  override Void onStart()
  {
    super.onStart
    ModbusLinkMgr.init(this)
  }

  override Void onStop()
  {
    super.onStop
    ModbusLinkMgr.stop
  }

  ** Modbus has no discovery, so learn walks whatever describes the device:
  ** its device spec if one is named, otherwise its register map. The root
  ** level is a folder per register type, and the learn arg naming one of
  ** those types returns its points.
  override Future onLearn(Conn conn, Obj? arg)
  {
    type := arg == null ? null : ModbusAddrType.fromStr(arg.toStr, false)
    if (arg != null && type == null) throw FaultErr("Invalid learn arg: ${arg}")

    deviceSpec := conn.rec["modbusDeviceSpec"]
    if (deviceSpec != null)
      return Future.makeCompletable.complete(learnSpec(proj.ns, deviceSpec.toStr, type))

    regUri := conn.rec["modbusRegMapUri"]
    if (regUri == null || regUri == ``)
      throw FaultErr("Learn requires 'modbusDeviceSpec' or 'modbusRegMapUri'")
    return Future.makeCompletable.complete(learnRegMap(ModbusRegMap.fromConn(proj, conn.rec), type))
  }

  ** Learn the points of a device spec: the register types in use, or the
  ** points of one of them.
  internal static Grid learnSpec(Namespace ns, Str qname, ModbusAddrType? type)
  {
    spec := ModbusDev.resolveSpec(ns, qname, "modbusDeviceSpec")

    byType := ModbusAddrType:Spec[][:]
    spec.slot("points", false)?.slots?.each |pt|
    {
      // an addr which does not parse has no register to learn
      addr := addrOf(pt)
      if (addr != null) byType.getOrAdd(addr.type) { Spec[,] }.add(pt)
    }
    if (type == null) return learnFolders(byType.keys)

    pts := (byType[type] ?: Spec[,]).sort |a, b| { addrOf(a).num <=> addrOf(b).num }
    return Etc.makeDictsGrid(null, pts.map |pt->Dict| { learnPoint(pt) })
  }

  ** Learn the registers of a register map, grouped the same way
  internal static Grid learnRegMap(ModbusRegMap regMap, ModbusAddrType? type)
  {
    byType := ModbusAddrType:ModbusReg[][:]
    regMap.regs.each |reg| { byType.getOrAdd(reg.addr.type) { ModbusReg[,] }.add(reg) }
    if (type == null) return learnFolders(byType.keys)

    regs := (byType[type] ?: ModbusReg[,]).sort |a, b| { a.addr.num <=> b.addr.num }
    return Etc.makeDictsGrid(null, regs.map |reg->Dict| { learnReg(reg) })
  }

  ** Root level: one folder per register type in use, in Modicon order. The
  ** learn key is a scalar because the nav tree round-trips it through a ref.
  private static Grid learnFolders(ModbusAddrType[] types)
  {
    rows := types.sort |a, b| { a.ordinal <=> b.ordinal }.map |t->Dict|
    {
      Etc.makeDict(["dis": "${t.toLocale}s", "learn": t.name])
    }
    return Etc.makeDictsGrid(null, rows)
  }

  ** Learn row for one point, addressing its registers by the point's qname
  private static Dict learnPoint(Spec pt)
  {
    cur   := pt.slot("modbusCurAddr", false)
    write := pt.slot("modbusWriteAddr", false)
    acc   := Str:Obj[:] { ordered = true }
    acc["dis"]   = ModbusReg.disOf(cur ?: write) ?: pt.name
    acc["point"] = Marker.val
    kind := ModbusReg.slotVal(pt, "kind")
    unit := ModbusReg.slotVal(pt, "unit")
    if (kind  != null) acc["kind"]        = kind
    if (unit  != null) acc["unit"]        = unit
    if (cur   != null) acc["modbusCur"]   = pt.qname
    if (write != null) acc["modbusWrite"] = pt.qname
    return Etc.dictFromMap(acc)
  }

  ** Learn row for one register of a register map
  private static Dict learnReg(ModbusReg reg)
  {
    acc := Str:Obj[:] { ordered = true }
    acc["dis"]   = reg.dis
    acc["point"] = Marker.val
    acc["kind"]  = reg.data.kind.toStr
    if (reg.readable)     acc["modbusCur"]   = reg.name
    if (reg.writable)     acc["modbusWrite"] = reg.name
    if (reg.unit != null) acc["unit"]        = reg.unit.toStr
    reg.tags.each |v, n| { acc[n] = v }
    return Etc.dictFromMap(acc)
  }

  ** Parsed address of the point's cur addr, else its write addr
  private static ModbusAddr? addrOf(Spec pt)
  {
    a := pt.slot("modbusCurAddr", false) ?: pt.slot("modbusWriteAddr", false)
    if (a == null) return null
    s := ModbusReg.slotVal(a, "addr")
    return s == null ? null : ModbusAddr.fromStr(s, false)
  }

  internal Grid read(Obj conn, Str[] regs)
  {
    this.conn(Etc.toId(conn)).send(HxMsg("modbus.read", regs.toImmutable)).get
  }

  internal Void write(Obj conn, Str reg, Obj val)
  {
    this.conn(Etc.toId(conn)).send(HxMsg("modbus.write", reg, val)).get
  }
}

