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
    Context.cur.proj.ext("hx.modbus", checked)
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

  override Future onLearn(Conn conn, Obj? arg)
  {
    regMap := ModbusRegMap.fromConn(proj, conn.rec)
    tagMap := Str:Str[:]
    regMap.regs.each |reg|
    {
      names := Etc.dictNames(reg.tags)
      tagMap.setList(names) |n| { n }
    }
    tags := tagMap.keys.sort

    gb := GridBuilder()
      .addCol("dis").addCol("kind").addCol("modbusCur")
      .addCol("modbusWrite").addCol("point").addCol("unit")
      .addColNames(tags)
    regMap.regs.each |reg|
    {
      row := Obj?[
        reg.dis,
        reg.data.kind.toStr,
        reg.readable ? reg.name : null,
        reg.writable ? reg.name : null,
        Marker.val,
        reg.unit?.toStr,
      ]
      tags.each |n| { row.add(reg.tags[n]) }
      gb.addRow(row)
    }
    return Future.makeCompletable.complete(gb.toGrid)
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

