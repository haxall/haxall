//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jul 2012  Andy Frank       Creation
//  13 Jan 2022  Matthew Giannini Redesign for Haxall
//

using concurrent
using inet

**
** ModbusMaster implements the master interface to slave devices.
**
@NoDoc
class ModbusMaster
{
  ** Create new master.
  new make(ModbusTransport transport)
  {
    this.transport = transport
  }

  ** Open transport for communication.
  This open()
  {
    transport.open
    return this
  }

  ** Close transport.
  This close()
  {
    transport.close
    return this
  }

  Void withTrace(Log log, |This| f)
  {
    curLog := transport.log
    try
    {
      transport.log = log
      f(this)
    }
    finally
    {
      transport.log = curLog
    }
  }

//////////////////////////////////////////////////////////////////////////
// Coils
//////////////////////////////////////////////////////////////////////////

  ** Convenience for 'readCoils(slave, addr, 1)'.
  Bool readCoil(Int slave, Int addr)
  {
    readCoils(slave, addr, 1).first
  }

  ** Read coils. Returns map of coil address to bool state.
  Bool[] readCoils(Int slave, Int start, Int count)
  {
    readBinary(slave, 0x01, start, count)
  }

  ** Write a coil value.
  Void writeCoil(Int slave, Int addr, Bool val)
  {
    writeBinary(slave, 0x05, addr, val)
  }

//////////////////////////////////////////////////////////////////////////
// Discrete Inputs
//////////////////////////////////////////////////////////////////////////

  ** Convenience for 'readDiscreteInputs(slave, addr, 1)'.
  Bool readDiscreteInput(Int slave, Int addr)
  {
    readDiscreteInputs(slave, addr, 1).first
  }

  ** Read coils. Returns map of coil address to bool state.
  Bool[] readDiscreteInputs(Int slave, Int start, Int count)
  {
    readBinary(slave, 0x02, start, count)
  }

//////////////////////////////////////////////////////////////////////////
// Input Registers
//////////////////////////////////////////////////////////////////////////

  ** Convenince for 'readInputRegs(slave, addr, 1)'.
  Int readInputReg(Int slave, Int addr)
  {
    readInputRegs(slave, addr, 1).first
  }

  ** Read input registers. Returns map of address to register value.
  Int[] readInputRegs(Int slave, Int start, Int count)
  {
    read16(slave, 0x04, start, count)
  }

//////////////////////////////////////////////////////////////////////////
// Holding Registers
//////////////////////////////////////////////////////////////////////////

  ** Convenince for 'readHoldRegs(slave, addr, 1)'.
  Int readHoldingReg(Int slave, Int addr)
  {
    readHoldingRegs(slave, addr, 1).first
  }

  ** Read holding registers. Returns map of address to register value.
  Int[] readHoldingRegs(Int slave, Int start, Int count)
  {
    read16(slave, 0x03, start, count)
  }

  ** Write a single holding register value.
  Void writeHoldingReg(Int slave, Int addr, Int val)
  {
    write16(slave, 0x06, addr, [val])
  }

  ** Write multiple holding register values, where each 'val' is a
  ** 16-bit value written consecutively starting at 'startAddr'.
  Void writeHoldingRegs(Int slave, Int start, Int[] vals)
  {
    if (vals.size == 1) writeHoldingReg(slave, start, vals.first)
    else write16(slave, 0x10, start, vals)
  }

  // TODO: our normal writeHoldingRegs opts out of the func code,
  // which was probably the wrong decision; so add this internal
  // method to force using 0x10 even for single reg writes
  internal Void _writeHoldingRegs(Int slave, Int start, Int[] vals)
  {
    write16(slave, 0x10, start, vals, true)
  }

//////////////////////////////////////////////////////////////////////////
// Support
//////////////////////////////////////////////////////////////////////////

  ** Read binary data. Returns map of address to bool state.
  private Bool[] readBinary(Int slave, Int func, Int start, Int count)
  {
    // format message
    msg := Buf()
    out := msg.out
    out.write(slave)
    out.write(func)
    out.writeI2(start)
    out.writeI2(count)
    addCrc(msg)

    // req response
    in := transport.req(msg)
    try
    {
      // verify slave
      rslave := in.readU1
      if (slave != rslave) throw Err("Slave mismatch $slave != $rslave")

      // verify func
      fc := in.readU1
      if (isErr(fc)) throw err(in)
      if (fc != func) throw Err("Function code mismatch $func != $fc")

      // parse response
      list := Bool[,]
      cur  := 0
      len  := in.readU1  // not used
      count.times |i|
      {
        if (i == 0 || i % 8 == 0) cur = in.readU1
        list.add(cur.and(0x01) == 1)
        cur = cur.shiftr(1)
      }
      verifyCrc(in)
      return list
    }
    finally
    {
      // flush trace
      in.close
    }
  }

  ** Write binary data.
  private Void writeBinary(Int slave, Int func, Int addr, Bool val)
  {
    // format message
    msg := Buf()
    out := msg.out
    out.write(slave)
    out.write(func)
    out.writeI2(addr)
    out.writeI2(val ? 0xff00 : 0)
    addCrc(msg)

    // req response
    in := transport.req(msg)
    try
    {
      // verify slave
      rslave := in.readU1
      if (slave != rslave) throw Err("Slave mismtach $slave != $rslave")

      // verify func
      fc := in.readU1
      if (isErr(fc)) throw err(in)
      if (fc != func) throw Err("Function code mismatch $func != $fc")

      // parse response
      raddr := in.readU2  // echo write addr
      rval  := in.readU2  // echo write val or count
      verifyCrc(in)
    }
    finally
    {
      // flush trace
      in.close
    }
  }

  ** Read 16-bit data from given slave device. Returns map
  ** of address to register value.
  private Int[] read16(Int slave, Int func, Int start, Int count)
  {
    // format message
    msg := Buf()
    out := msg.out
    out.write(slave)
    out.write(func)
    out.writeI2(start)
    out.writeI2(count)
    addCrc(msg)

    // req response
    in := transport.req(msg)
    try
    {
      // verify slave
      rslave := in.readU1
      if (slave != rslave) throw Err("Slave mismtach $slave != $rslave")

      // verify func
      fc := in.readU1
      if (isErr(fc)) throw err(in)
      if (fc != func) throw Err("Function code mismatch $func != $fc")

      // parse response
      list := Int[,]
      len  := in.readU1 / 2
      len.times |i| { list.add(in.readU2) }
      verifyCrc(in)

      return list
    }
    finally
    {
      // flush trace
      in.close
    }
  }

  ** Write 16-bit data.
  private Void write16(Int slave, Int func, Int addr, Int[] vals, Bool forceMulti := false)
  {
    // format message
    len := vals.size
    msg := Buf()
    out := msg.out
    out.write(slave)
    out.write(func)
    out.writeI2(addr)
    if (len > 1 || forceMulti)
    {
      out.writeI2(len)  // quant of regs
      out.write(len*2)  // byte count
    }
    vals.each |v| { out.writeI2(v) }
    addCrc(msg)

    // req response
    in := transport.req(msg)
    try
    {
      // verify slave
      rslave := in.readU1
      if (slave != rslave) throw Err("Slave mismtach $slave != $rslave")

      // verify func
      fc := in.readU1
      if (isErr(fc)) throw err(in)
      if (fc != func) throw Err("Function code mismatch $func != $fc")

      // verify addr
      raddr := in.readU2
      if (addr != raddr) throw Err("Address mismatch $addr != $raddr")

      // parse remaining response
      rval := in.readU2  // echo write val or count
      verifyCrc(in)
    }
    finally
    {
      // flush trace
      in.close
    }
  }

  ** Check for error condition.
  private Bool isErr(Int code) { code.and(0x80) != 0 }

  ** Make error for expection code.
  private Err err(ModbusInStream in)
  {
    code := in.readU1
    msg  := ""
    switch (code)
    {
      case 1:   msg = "Illegal Function"
      case 2:   msg = "Illegal Data Address"
      case 3:   msg = "Illegal Data Value"
      case 4:   msg = "Slave Device Failure"
      case 5:   msg = "Acknowledge"
      case 6:   msg = "Slave Device Busy"
      case 7:   msg = "Negative Acknowledge"
      case 8:   msg = "Memory Parity Error"
      case 10:  msg = "Gateway Path Unavailable"
      case 11:  msg = "Gateway Target Device Failed to Respond"
      default:  msg = "Unknown code"
    }
    return Err("Exception code $code: $msg")
  }

  ** Add CRC to message if supported.
  private Void addCrc(Buf msg)
  {
    if (!transport.useCrc) return
    crc := msg.crc("CRC-16")
    msg.write(crc)            // LSB of CRC
    msg.write(crc.shiftr(8))  // MSB of CRC
  }

  ** Verify CRC if supported.
  private Void verifyCrc(ModbusInStream msg)
  {
    if (!transport.useCrc) return
    computed := msg.data.crc("CRC-16")
    expected := msg.readU1.or(msg.readU1.shiftl(8))  // read lower CRC byte first
    if (computed != expected) throw Err("Invalid CRC $computed.toHex != $expected.toHex")
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private ModbusTransport transport
}