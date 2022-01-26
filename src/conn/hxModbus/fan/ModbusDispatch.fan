//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jul 2012  Andy Frank         Creation
//   8 Dec 2016  Andy Frank         Redesign to use ModbusLink
//  12 Jan 2022  Matthew Giannini   Redesign for Haxall
//

using concurrent
using haystack
using folio
using hx
using hxConn

**
** Dispatch callbacks for the Modbus connector
**
class ModbusDispatch : ConnDispatch
{
  new make(Obj arg) : super(arg)
  {
  }

  private static const Number defGaps := Number.zero
  private static const Number defMax  := Number.makeInt(100)

  private ModbusDev? dev
  private ModbusLink? link

//////////////////////////////////////////////////////////////////////////
// Receive
//////////////////////////////////////////////////////////////////////////

  override Obj? onReceive(HxMsg msg)
  {
    switch (msg.id)
    {
      case "modbus.read":  return mread(msg.a)
      case "modbus.write": return mwrite(msg.a, msg.b)
      default:             return super.onReceive(msg)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Open/Ping/Close
//////////////////////////////////////////////////////////////////////////

  override Void onOpen()
  {
    this.dev  = ModbusDev.fromConn(conn)
    this.link = ModbusLink.get(dev.uri)
  }

  override Void onClose()
  {
    this.link?.close
    this.link = null
    this.dev  = null
  }

  override Dict onPing()
  {
    try { link.ping(dev) }
    catch (Err err) { close(err); throw err }
    return Etc.emptyDict
  }

//////////////////////////////////////////////////////////////////////////
// Learn
//////////////////////////////////////////////////////////////////////////

  override Grid onLearn(Obj? arg)
  {
    if (dev == null) throw Err("Not open")
    tagMap := Str:Str[:]
    dev.regMap.regs.each |reg|
    {
      names := Etc.dictNames(reg.tags)
      tagMap.setList(names) |n| { n }
    }
    tags := tagMap.keys.sort

    gb := GridBuilder()
      .addCol("dis").addCol("kind").addCol("modbusCur")
      .addCol("modbusWrite").addCol("point").addCol("unit")
      .addColNames(tags)
    dev.regMap.regs.each |reg|
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
    return gb.toGrid
  }

//////////////////////////////////////////////////////////////////////////
// Sync Cur
//////////////////////////////////////////////////////////////////////////

  override Void onSyncCur(ConnPoint[] points)
  {
    try
    {
      regs := mapToRegs(points)
      toBlocks(regs).each |block|
      {
        link.readBlock(dev, block)
        updateVals(points, block)
      }
    }
    catch (Err err) { close(err) }
  }

  private Grid mread(Str[] regNames)
  {
    open
    try
    {
      gb := GridBuilder()
      gb.addColNames(["name","val"])
      regs := regNames.map |n| { dev.regMap.reg(n) }
      toBlocks(regs).each |block|
      {
        link.readBlock(dev, block)
        block.regs.each |r,i| { gb.addRow2(r.name, block.vals[i]) }
      }
      return gb.toGrid
    }
    catch (Err err)
    {
      close(err)
      throw err
    }
  }

  private ModbusBlock[] toBlocks(ModbusReg[] regs)
  {
    gaps := rec["modbusBlockGap"] as Number ?: defGaps
    max  := rec["modbusBlockMax"] as Number ?: defMax
    return ModbusBlock.optimize(regs, gaps.toInt, max.toInt)
  }

  private ModbusReg[] mapToRegs(ConnPoint[] points)
  {
    regs := ModbusReg[,]
    points.each |p|
    {
      try
      {
        cur := p.rec["modbusCur"] ?: throw FaultErr("Missing modbusCur")
        reg := dev.regMap.reg(cur)
        regs.add(reg)
      }
      catch (Err err) { p.updateCurErr(err) }
    }
    return regs
  }

  private Void updateVals(ConnPoint[] points, ModbusBlock block)
  {
    block.regs.each |r,i|
    {
      val := block.vals[i]
      pts := points.findAll |x| { x.rec->modbusCur == r.name }
      pts.each |p|
      {
        if (val is Err) p.updateCurErr(val)
        else p.updateCurOk(val)
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Write
//////////////////////////////////////////////////////////////////////////

  private Obj? mwrite(Str regName, Obj val)
  {
    open
    try
    {
      reg := dev.regMap.reg(regName)
      link.write(dev, reg, val)
      return null
    }
    catch (Err err)
    {
      close(err)
      throw err
    }
  }


  override Void onWrite(ConnPoint point, ConnWriteInfo event)
  {
    try
    {
      if (event.val != null)
      {
        write := point.rec["modbusWrite"] ?: throw FaultErr("Missing modbusWrite")
        reg   := dev.regMap.reg(write)
        link.write(dev, reg, event.val)
      }
      point.updateWriteOk(event)
    }
    catch (Err err)
    {
      point.updateWriteErr(event, err)
      close(err)
    }
  }
}