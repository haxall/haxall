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

  ** See `ModbusTransport.isFramed`.
  Bool isFramed() { transport.isFramed }

  ** Minimum silence to enforce on the wire between transactions.
  ** See `ModbusTransport.quietTime`.
  Duration quietTime
  {
    get { transport.quietTime }
    set { transport.quietTime = it }
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

  ** Write a single coil value using function code 0x05.
  Void writeCoil(Int slave, Int addr, Bool val)
  {
    writeSingle(slave, 0x05, addr, val ? 0xff00 : 0)
  }

  ** Write coil values consecutively starting at 'start' using function
  ** code 0x0f. This always uses 0x0f, even to write a single coil.
  Void writeCoils(Int slave, Int start, Bool[] vals)
  {
    bits := Buf().fill(0, (vals.size + 7) / 8)
    vals.each |v, i| { if (v) bits[i / 8] = bits[i / 8].or(1.shiftl(i % 8)) }
    writeMulti(slave, 0x0f, start, vals.size, bits)
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

  ** Write a single holding register value using function code 0x06.
  Void writeHoldingReg(Int slave, Int addr, Int val)
  {
    writeSingle(slave, 0x06, addr, val)
  }

  ** Write 16-bit holding register values consecutively starting at 'start'
  ** using function code 0x10. This always uses 0x10, even to write a single
  ** register.
  Void writeHoldingRegs(Int slave, Int start, Int[] vals)
  {
    data := Buf()
    vals.each |v| { data.writeI2(v) }
    writeMulti(slave, 0x10, start, vals.size, data)
  }

//////////////////////////////////////////////////////////////////////////
// Support
//////////////////////////////////////////////////////////////////////////

  ** Read binary data. Returns map of address to bool state.
  private Bool[] readBinary(Int slave, Int func, Int start, Int count)
  {
    in := req(slave, func) |out| { out.writeI2(start).writeI2(count) }
    try
    {
      list := Bool[,]
      cur  := 0
      len  := in.readU1  // not used
      count.times |i|
      {
        if (i % 8 == 0) cur = in.readU1
        list.add(cur.and(0x01) == 1)
        cur = cur.shiftr(1)
      }
      verifyCrc(in)
      return list
    }
    finally in.close
  }

  ** Read 16-bit data from given slave device. Returns map
  ** of address to register value.
  private Int[] read16(Int slave, Int func, Int start, Int count)
  {
    in := req(slave, func) |out| { out.writeI2(start).writeI2(count) }
    try
    {
      list := Int[,]
      len  := in.readU1 / 2
      len.times { list.add(in.readU2) }
      verifyCrc(in)
      return list
    }
    finally in.close
  }

  ** Write a single 16-bit value (0x05, 0x06).
  private Void writeSingle(Int slave, Int func, Int addr, Int val)
  {
    in := req(slave, func) |out| { out.writeI2(addr).writeI2(val) }
    try
    {
      verifyEcho(in, "Address", addr)
      in.readU2  // echo val
      verifyCrc(in)
    }
    finally in.close
  }

  ** Write 'count' consecutive values packed into 'data' (0x0f, 0x10).
  private Void writeMulti(Int slave, Int func, Int start, Int count, Buf data)
  {
    in := req(slave, func) |out|
    {
      out.writeI2(start).writeI2(count).write(data.size).writeBuf(data.seek(0))
    }
    try
    {
      verifyEcho(in, "Address", start)
      verifyEcho(in, "Quantity", count)
      verifyCrc(in)
    }
    finally in.close
  }

  ** Send request with given slave and function code, where 'body' writes
  ** the payload. Verify the response header and return the stream to read
  ** the rest of the response. The caller must close it to flush the trace.
  private ModbusInStream req(Int slave, Int func, |OutStream| body)
  {
    // format message
    msg := Buf()
    msg.out.write(slave).write(func)
    body(msg.out)
    addCrc(msg)

    // req response
    in := transport.req(msg)
    try
    {
      rslave := in.readU1
      if (slave != rslave) throw Err("Slave mismatch ${slave} != ${rslave}")

      fc := in.readU1
      if (isErr(fc)) throw err(in)
      if (fc != func) throw Err("Function code mismatch ${func} != ${fc}")

      return in
    }
    catch (Err e) { in.close; throw e }
  }

  ** Verify a 16-bit value echoed back in a write response.
  private Void verifyEcho(ModbusInStream in, Str name, Int expected)
  {
    actual := in.readU2
    if (expected != actual) throw Err("${name} mismatch ${expected} != ${actual}")
  }

  ** Check for error condition.
  private Bool isErr(Int code) { code.and(0x80) != 0 }

  ** Make error for exception response. The CRC must be consumed so
  ** the frame is fully read off the wire.
  private Err err(ModbusInStream in)
  {
    code := in.readU1
    verifyCrc(in)
    return ModbusExceptionErr(code)
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

**************************************************************************
** ModbusExceptionErr
**************************************************************************

**
** ModbusExceptionErr is raised when a slave returns a valid exception
** response. The response was fully read, so the wire is still in sync.
**
@NoDoc const class ModbusExceptionErr : Err
{
  ** Construct with exception code from the response
  new make(Int code) : super("Exception code ${code}: ${codeToMsg(code)}")
  {
    this.code = code
  }

  ** Exception code from the response
  const Int code

  private static Str codeToMsg(Int code)
  {
    switch (code)
    {
      case 1:   return "Illegal Function"
      case 2:   return "Illegal Data Address"
      case 3:   return "Illegal Data Value"
      case 4:   return "Slave Device Failure"
      case 5:   return "Acknowledge"
      case 6:   return "Slave Device Busy"
      case 7:   return "Negative Acknowledge"
      case 8:   return "Memory Parity Error"
      case 10:  return "Gateway Path Unavailable"
      case 11:  return "Gateway Target Device Failed to Respond"
      default:  return "Unknown code"
    }
  }
}
