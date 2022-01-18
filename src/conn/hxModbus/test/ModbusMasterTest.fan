//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Jul 2013  Andy Frank  Creation
//

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
    t.test = toBuf("018305"); verifyErr(Err#) { m.readHoldingReg(1, 0) }

    // test transport.send without CRC
    t.crc  = false
    t.test = toBuf("0103020007"); verifyEq(m.readHoldingReg(1, 0), 7)
    t.test = toBuf("018307"); verifyErr(Err#) { m.readHoldingReg(1, 0) }

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
    t.test = toBuf("01060001000a"); m.writeHoldingRegs(1, 1, [10])
    t.test = toBuf("01060002000b"); m.writeHoldingReg(1, 2, 11)
    t.test = toBuf("05060003000c"); m.writeHoldingReg(5, 3, 12)

    t.test = toBuf("011000010002"); m.writeHoldingRegs(1, 1, [10,11])
    t.test = toBuf("011000050003"); m.writeHoldingRegs(1, 5, [10,11,12])
    t.test = toBuf("021000070004"); m.writeHoldingRegs(2, 7, [10,11,12,20])

    // errs
    t.test = toBuf("0103020001"); verifyErr(Err#) { m.readHoldingReg(3, 0) }       // wrong slave
    t.test = toBuf("0105020001"); verifyErr(Err#) { m.readHoldingReg(1, 0) }       // wrong func
    t.test = toBuf("0107020001"); verifyErr(Err#) { m.writeHoldingReg(1, 0, 22) }  // wrong func
    t.test = toBuf("018305");     verifyErr(Err#) { m.readHoldingReg(1, 0) }
    t.test = toBuf("018305");     verifyErr(Err#) { m.readHoldingRegs(1, 0, 10) }
    t.test = toBuf("018601");     verifyErr(Err#) { m.writeHoldingReg(1, 0, 3) }
    t.test = toBuf("019001");     verifyErr(Err#) { m.writeHoldingRegs(1, 0, [1,2,3]) }
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
  Bool crc   := true
  Buf test   := Buf()

  override Void open() { _open=true }
  override Void close() { _open=false }
  override Bool useCrc() { crc }

  override InStream req(Buf msg)
  {
    // echo("TestTransport.req [crc=$crc]:
    //         req: $msg.toHex [$msg.size]
    //         res: $test.toHex [$test.size]")
    return toRes(test).in
  }

  private Buf toRes(Buf buf)
  {
    if (useCrc)
    {
      crc := buf.crc("CRC-16")
      buf.write(crc)            // LSB of CRC
      buf.write(crc.shiftr(8))  // MSB of CRC
    }
    return buf.flip
  }
}
