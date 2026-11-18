//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Nov 2026  Matthew Giannini  Creation
//

using concurrent
using inet
using haystack
using hxPlatformSerial

**
** ModbusTimeoutTest
**
class ModbusTimeoutTest : Test
{

//////////////////////////////////////////////////////////////////////////
// RTU
//////////////////////////////////////////////////////////////////////////

  Void testRtu()
  {
    port := FakeSerialSocket()
    m := ModbusMaster(ModbusRtuTransport(port)).open

    // default waits 1sec
    port.respond(res, 300ms)
    verifyEq(m.readHoldingReg(1, 0), 5)

    // a response slower than the default is read with a longer timeout
    m.responseTimeout = 2sec
    port.respond(res, 1500ms)
    verifyEq(m.readHoldingReg(1, 0), 5)

    // a late response times out without an IOErr, which would recycle the
    // port for every slave on the line
    m.responseTimeout = 100ms
    port.respond(res, 500ms)
    verifyErrMsg(ModbusTimeoutErr#, "Response timeout after 100ms") { m.readHoldingReg(1, 0) }
    verifyEq(ModbusTimeoutErr#.fits(IOErr#), false)

    // silent device
    m.responseTimeout = 200ms
    port.respond(null, 0ms)
    t1 := Duration.now
    verifyErr(ModbusTimeoutErr#) { m.readHoldingReg(1, 0) }
    verify(Duration.now - t1 >= 200ms)

    // a late response to the previous request is purged, not read as
    // the response to this one
    m.responseTimeout = null
    port.stale = toRtu("0103020009").seek(0)
    port.respond(res, 100ms)
    verifyEq(m.readHoldingReg(1, 0), 5)
    verifyEq(port.stale.size, 0)

    // a line that never goes quiet ends the read at the max frame size
    port.respond(Buf().fill(0xff, 1000), 0ms)
    verifyErr(Err#) { m.readHoldingReg(1, 0) }
    verifyEq(port.res.remaining, 1000 - 256)
  }

  private Buf res() { toRtu("0103020005") }

  private Buf toRtu(Str hex)
  {
    buf := Buf.fromHex(hex)
    crc := buf.crc("CRC-16")
    return buf.seek(buf.size).write(crc).write(crc.shiftr(8))
  }

//////////////////////////////////////////////////////////////////////////
// TCP
//////////////////////////////////////////////////////////////////////////

  Void testTcp()
  {
    listener := TcpListener().bind(IpAddr("127.0.0.1"), null)
    serve(listener, 300ms)
    try
    {
      // the socket default is the constructor timeout
      m := ModbusMaster(ModbusTcpTransport(IpAddr("127.0.0.1"), listener.localPort, 5sec)).open
      verifyEq(m.readHoldingReg(1, 0), 0)

      // the response timeout applies to the live socket per request
      m.responseTimeout = 100ms
      verifyErr(IOErr#) { m.readHoldingReg(1, 0) }
      m.close

      m.open
      m.responseTimeout = 1sec
      verifyEq(m.readHoldingReg(1, 0), 0)
      m.close
    }
    finally listener.close
  }

  ** Answer every read on listener with zeros after delay
  private Void serve(TcpListener listener, Duration delay)
  {
    Actor(ActorPool()) |Unsafe msg->Obj?|
    {
      TcpListener l := msg.val
      while (true)
      {
        TcpSocket? s
        try s = l.accept
        catch (Err e) return null
        try
        {
          while (true)
          {
            req := s.in.readBufFully(null, 12)
            tx  := req.readU2
            req.readU2; req.readU2
            unit := req.read
            fc   := req.read
            req.readU2
            count := req.readU2
            Actor.sleep(delay)
            out := s.out
            out.writeI2(tx).writeI2(0).writeI2(3 + count * 2)
            out.write(unit).write(fc).write(count * 2)
            count.times { out.writeI2(0) }
            out.flush
          }
        }
        catch (IOErr e) {}
        finally s.close
      }
      return null
    }.send(Unsafe(listener))
  }
}

**************************************************************************
** FakeSerialSocket
**************************************************************************

** Serial slave which answers each request after a delay
internal class FakeSerialSocket : SerialSocket
{
  new make() : super(SerialPort(Etc.makeDict(["name":"test", "device":"/test"])),
                     SerialConfig.fromStr("test-9600-8n1-none"))
  {
    this.fakeIn = FakeSerialIn(this)
  }

  ** Answer the next request with res after delay, or never if null
  Void respond(Buf? res, Duration delay)
  {
    this.res = res?.dup?.seek(0)
    this.resAt = Duration.now + delay
  }

  override InStream in() { fakeIn }

  override OutStream out() { reqs.out }

  override This purge() { stale.clear; return this }

  ** Bytes already waiting to be read when the next request is sent
  Buf stale := Buf()

  Buf? res
  Duration resAt := Duration.now
  Buf reqs := Buf()
  private FakeSerialIn fakeIn
}

internal class FakeSerialIn : InStream
{
  new make(FakeSerialSocket port) : super(null) { this.port = port }

  override Int avail() { cur?.remaining ?: 0 }

  override Int? read() { cur?.read }

  override Int? readBuf(Buf buf, Int n)
  {
    b := read
    if (b == null) return null
    buf.write(b)
    return 1
  }

  override This unread(Int b) { throw UnsupportedErr() }

  private Buf? cur()
  {
    if (port.stale.remaining > 0) return port.stale
    if (port.res != null && Duration.now >= port.resAt) return port.res
    return null
  }

  private FakeSerialSocket port
}
