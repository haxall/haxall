//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    9 Jul 2012  Andy Frank        Creation
//   12 Jan 2022  Matthew Giannini  Redesign for Haxall
//

using haystack
using hx
using hxConn

**
** Modbus connector library
**
const class ModbusLib : ConnLib
{
  static ModbusLib? cur(Bool checked := true)
  {
    HxContext.curHx.rt.lib("modbus", checked)
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

  internal Grid read(Obj conn, Str[] regs)
  {
    this.conn(Etc.toId(conn)).send(HxMsg("modbus.read", regs.toImmutable)).get
  }

  internal Void write(Obj conn, Str reg, Obj val)
  {
    this.conn(Etc.toId(conn)).send(HxMsg("modbus.write", reg, val)).get
  }
}