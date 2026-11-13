//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Jul 2013  Andy Frank  Creation
//

using inet
using haystack

**************************************************************************
** ModbusMasterTest
**************************************************************************

internal class ModbusMasterTest : Test
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics()
  {
    t := ModbusTestTransport()
    m := ModbusMaster(t)

    // test transport.open
    verifyEq(t._open, false)
    m.open
    verifyEq(t._open, true)

    // test transport.send with CRC
    t.crc  = true
    t.test = toBuf("0103020005"); verifyEq(m.readHoldingReg(1, 0), 5)
    t.test = toBuf("018305"); verifyErr(ModbusExceptionErr#) { m.readHoldingReg(1, 0) }

    // test transport.send without CRC
    t.crc  = false
    t.test = toBuf("0103020007"); verifyEq(m.readHoldingReg(1, 0), 7)
    t.test = toBuf("018307"); verifyErr(ModbusExceptionErr#) { m.readHoldingReg(1, 0) }

    // test transport.close
    m.close
    verifyEq(t._open, false)
  }

//////////////////////////////////////////////////////////////////////////
// Coils
//////////////////////////////////////////////////////////////////////////

  Void testDiscreteCoils()
  {
    t := ModbusTestTransport()
    m := ModbusMaster(t).open

    // read
    t.test = toBuf("01010100"); verifyEq(m.readCoil(1, 1), false)
    t.test = toBuf("01010101"); verifyEq(m.readCoil(1, 1), true)
    t.test = toBuf("01010101"); verifyEq(m.readCoil(1, 2), true)
    t.test = toBuf("01010101"); verifyEq(m.readCoil(1, 5), true)

    t.test = toBuf("01010101"); verifyEq(m.readCoils(1, 1, 1), [true])
    t.test = toBuf("01010103"); verifyEq(m.readCoils(1, 1, 3), [true,  true,  false])
    t.test = toBuf("01010104"); verifyEq(m.readCoils(1, 1, 3), [false, false, true])

    // write
    t.test = toBuf("010500040000"); m.writeCoil(1, 4, false)
    t.test = toBuf("01050004ff00"); m.writeCoil(1, 4, true)

    // errs
    t.test = toBuf("01010100"); verifyErr(Err#) { m.readCoil(3, 0) }         // wrong slave
    t.test = toBuf("01070100"); verifyErr(Err#) { m.readCoil(1, 0) }         // wrong func
    t.test = toBuf("01070100"); verifyErr(Err#) { m.writeCoil(1, 4, true) }  // wrong func
  }

//////////////////////////////////////////////////////////////////////////
// Holding Registers
//////////////////////////////////////////////////////////////////////////

  Void testHoldingRegs()
  {
    t := ModbusTestTransport()
    m := ModbusMaster(t).open

    // read
    t.test = toBuf("0103020001"); verifyEq(m.readHoldingReg(1, 100), 1)
    t.test = toBuf("0203020002"); verifyEq(m.readHoldingReg(2, 100), 2)
    t.test = toBuf("0203020003"); verifyEq(m.readHoldingReg(2, 5), 3)

    t.test = toBuf("050302000a");         verifyEq(m.readHoldingRegs(5, 100, 1), [10])
    t.test = toBuf("010304000a000b");     verifyEq(m.readHoldingRegs(1, 100, 2), [10, 11])
    t.test = toBuf("010306000a000b000c"); verifyEq(m.readHoldingRegs(1, 100, 3), [10, 11, 12])

    // write
    t.test = toBuf("01060001000a"); m.writeHoldingReg(1, 1, 10)
    t.test = toBuf("011000010001"); m.writeHoldingRegs(1, 1, [10])
    t.test = toBuf("01060002000b"); m.writeHoldingReg(1, 2, 11)
    t.test = toBuf("05060003000c"); m.writeHoldingReg(5, 3, 12)

    t.test = toBuf("011000010002"); m.writeHoldingRegs(1, 1, [10,11])
    t.test = toBuf("011000050003"); m.writeHoldingRegs(1, 5, [10,11,12])
    t.test = toBuf("021000070004"); m.writeHoldingRegs(2, 7, [10,11,12,20])

    // errs
    t.test = toBuf("0103020001"); verifyErr(Err#) { m.readHoldingReg(3, 0) }       // wrong slave
    t.test = toBuf("0105020001"); verifyErr(Err#) { m.readHoldingReg(1, 0) }       // wrong func
    t.test = toBuf("0107020001"); verifyErr(Err#) { m.writeHoldingReg(1, 0, 22) }  // wrong func
    t.test = toBuf("018305");     verifyErr(ModbusExceptionErr#) { m.readHoldingReg(1, 0) }
    t.test = toBuf("018305");     verifyErr(ModbusExceptionErr#) { m.readHoldingRegs(1, 0, 10) }
    t.test = toBuf("018601");     verifyErr(ModbusExceptionErr#) { m.writeHoldingReg(1, 0, 3) }
    t.test = toBuf("019001");     verifyErr(ModbusExceptionErr#) { m.writeHoldingRegs(1, 0, [1,2,3]) }
  }

//////////////////////////////////////////////////////////////////////////
// Write Requests
//////////////////////////////////////////////////////////////////////////

  Void testWriteReqs()
  {
    t := ModbusTestTransport()
    m := ModbusMaster(t).open
    t.crc = false

    // single writes
    verifyWrite(t, "01050004ff00", "01050004ff00") |->| { m.writeCoil(1, 4, true) }
    verifyWrite(t, "010500040000", "010500040000") |->| { m.writeCoil(1, 4, false) }
    verifyWrite(t, "01060001000a", "01060001000a") |->| { m.writeHoldingReg(1, 1, 10) }

    // coils pack LSB first, padded to a byte boundary
    verifyWrite(t, "010f000400010101", "010f00040001") |->| { m.writeCoils(1, 4, [true]) }
    verifyWrite(t, "010f000400010100", "010f00040001") |->| { m.writeCoils(1, 4, [false]) }
    verifyWrite(t, "010f00040008010d", "010f00040008") |->| { m.writeCoils(1, 4, [true,false,true,true,false,false,false,false]) }
    verifyWrite(t, "010f00040009020d01", "010f00040009") |->| { m.writeCoils(1, 4, [true,false,true,true,false,false,false,false,true]) }
    verifyWrite(t, "020f0000000a020d01", "020f0000000a") |->| { m.writeCoils(2, 0, [true,false,true,true,false,false,false,false,true,false]) }
    verifyWrite(t, "010f0000001002ffff", "010f00000010") |->| { m.writeCoils(1, 0, Bool[,].fill(true, 16)) }

    // holding regs always use 0x10, even for one register
    verifyWrite(t, "01100001000102000a", "011000010001") |->| { m.writeHoldingRegs(1, 1, [10]) }
    verifyWrite(t, "01100001000204000a000b", "011000010002") |->| { m.writeHoldingRegs(1, 1, [10,11]) }

    // response must echo the request
    t.test = toBuf("01050005ff00"); verifyErrMsg(Err#, "Address mismatch 4 != 5") { m.writeCoil(1, 4, true) }
    t.test = toBuf("010f00050001"); verifyErrMsg(Err#, "Address mismatch 4 != 5") { m.writeCoils(1, 4, [true]) }
    t.test = toBuf("010f00040002"); verifyErrMsg(Err#, "Quantity mismatch 1 != 2") { m.writeCoils(1, 4, [true]) }
    t.test = toBuf("011000010003"); verifyErrMsg(Err#, "Quantity mismatch 2 != 3") { m.writeHoldingRegs(1, 1, [10,11]) }
    t.test = toBuf("020f00040001"); verifyErrMsg(Err#, "Slave mismatch 1 != 2") { m.writeCoils(1, 4, [true]) }
    t.test = toBuf("011000040001"); verifyErrMsg(Err#, "Function code mismatch 15 != 16") { m.writeCoils(1, 4, [true]) }
  }

  private Void verifyWrite(ModbusTestTransport t, Str req, Str res, |->| f)
  {
    t.test = toBuf(res)
    f()
    verifyEq(t.lastReq.toHex, req)
  }

//////////////////////////////////////////////////////////////////////////
// Exception Responses
//////////////////////////////////////////////////////////////////////////

  Void testExceptionErr()
  {
    t := ModbusTestTransport()
    m := ModbusMaster(t).open

    // every request type raises typed err with code
    [true, false].each |crc|
    {
      t.crc = crc
      verifyExceptionErr(t, "018102", 2)  |->| { m.readCoil(1, 0) }
      verifyExceptionErr(t, "018502", 2)  |->| { m.writeCoil(1, 0, true) }
      verifyExceptionErr(t, "018303", 3)  |->| { m.readHoldingReg(1, 0) }
      verifyExceptionErr(t, "018401", 1)  |->| { m.readInputReg(1, 0) }
      verifyExceptionErr(t, "018604", 4)  |->| { m.writeHoldingReg(1, 0, 3) }
      verifyExceptionErr(t, "01900b", 11) |->| { m.writeHoldingRegs(1, 0, [1,2]) }
      verifyExceptionErr(t, "018f02", 2)  |->| { m.writeCoils(1, 0, [true]) }
    }

    // msg
    verifyEq(ModbusExceptionErr(2).msg,  "Exception code 2: Illegal Data Address")
    verifyEq(ModbusExceptionErr(99).msg, "Exception code 99: Unknown code")

    // exception response with bad CRC is not a valid exception
    t.crc = true
    t.badCrc = true
    t.test = toBuf("018302")
    try { m.readHoldingReg(1, 0); fail }
    catch (TestErr e) { throw e }
    catch (Err e) { verifyEq(e.typeof, Err#); verify(e.msg.startsWith("Invalid CRC")) }
  }

  private Void verifyExceptionErr(ModbusTestTransport t, Str res, Int code, |->| f)
  {
    t.test = toBuf(res)
    ModbusExceptionErr? err
    try { f(); fail }
    catch (ModbusExceptionErr e) { err = e }
    verifyEq(err.code, code)

    // CRC is consumed so the frame is fully read off the wire
    verifyEq(t.test.remaining, 0)
  }

//////////////////////////////////////////////////////////////////////////
// Framing
//////////////////////////////////////////////////////////////////////////

  Void testIsFramed()
  {
    // tcp delimits each response with its own header and length
    tcp := ModbusTcpTransport(IpAddr("127.0.0.1"), 502, 1sec)
    verifyEq(tcp.isFramed, true)
    verifyEq(ModbusMaster(tcp).isFramed, true)

    // rtu over tcp is a bare byte stream, so a bad frame desyncs it
    rtu := ModbusRtuTcpTransport(IpAddr("127.0.0.1"), 502, 1sec)
    verifyEq(rtu.isFramed, false)
    verifyEq(ModbusMaster(rtu).isFramed, false)
  }

//////////////////////////////////////////////////////////////////////////
// Frame Delay
//////////////////////////////////////////////////////////////////////////

  Void testFrameDelay()
  {
    t := ModbusTestTransport()
    m := ModbusMaster(t).open
    verifyEq(m.quietTime, 0sec)

    // default issues transactions back-to-back
    5.times { t.test = toBuf("0103020005"); m.readHoldingReg(1, 0) }
    verifyEq(t.reqTicks.size, 5)
    verify(t.reqTicks.last - t.reqTicks.first < 50ms.ticks)

    // quietTime forces silence between consecutive transactions
    t.reqTicks.clear
    m.quietTime = 50ms
    verifyEq(m.quietTime, 50ms)
    5.times { t.test = toBuf("0103020005"); m.readHoldingReg(1, 0) }
    verifyEq(t.reqTicks.size, 5)
    4.times |i| { verify(t.reqTicks[i+1] - t.reqTicks[i] >= 40ms.ticks) }

    // a failed transaction still stamps the wire as idle, so the
    // next request is paced rather than firing immediately
    t.reqTicks.clear
    t.test = toBuf("018305"); verifyErr(ModbusExceptionErr#) { m.readHoldingReg(1, 0) }
    t.test = toBuf("0103020005"); m.readHoldingReg(1, 0)
    verifyEq(t.reqTicks.size, 2)
    verify(t.reqTicks[1] - t.reqTicks[0] >= 40ms.ticks)
  }

//////////////////////////////////////////////////////////////////////////
// Support
//////////////////////////////////////////////////////////////////////////

  private Buf toBuf(Str str)
  {
    if (str.size % 2 != 0) throw Err("req does not end on byte boundry")
    buf := Buf()
    (str.size / 2).times |i|
    {
      x := i * 2
      s := str[x..x+1]
      buf.write(Int.fromStr(s, 16))
    }
    return buf
  }
}

**************************************************************************
** ModbusTestTransport
**************************************************************************

internal class ModbusTestTransport : ModbusTransport
{
  Bool _open := false
  Bool crc    := true
  Bool badCrc := false
  Buf test    := Buf()
  Buf? lastReq              // last request sent, including CRC
  Int[] reqTicks := Int[,]  // when each req hit the wire

  override Void open() { _open=true }
  override Void close() { _open=false }
  override Bool useCrc() { crc }

  override ModbusInStream req(Buf msg)
  {
    // echo("TestTransport.req [crc=$crc]:
    //         req: $msg.toHex [$msg.size]
    //         res: $test.toHex [$test.size]")
    pace
    lastReq = msg
    reqTicks.add(Duration.nowTicks)
    return ModbusInStream(toRes(test).in, Log.get("modbustest"), "", this)
  }

  private Buf toRes(Buf buf)
  {
    if (useCrc)
    {
      crc := buf.crc("CRC-16")
      if (badCrc) crc = crc.xor(0xffff)
      buf.write(crc)            // LSB of CRC
      buf.write(crc.shiftr(8))  // MSB of CRC
    }
    return buf.flip
  }
}
