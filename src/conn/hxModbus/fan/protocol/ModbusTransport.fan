//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Sep 2013  Andy Frank       Creation
//   13 Jan 2022  Matthew Giannini Redesign for Haxall
//

using concurrent
using inet
using hxSerial

**************************************************************************
** ModbusTransport provides a transport protocol for Modbus messaging.
**************************************************************************

@NoDoc
abstract class ModbusTransport
{
  ** Does this transport use CRC.
  virtual Bool useCrc() { true }

  ** Open transport for communication, or do nothing if already open.
  abstract Void open()

  ** Close transport, or do nothing if already closed.
  abstract Void close()

  ** Send a request to a slave device and return a ModbusInStream for response.
  abstract ModbusInStream req(Buf msg)

  // ** Respond to a master request.
  // abstract Buf res(...)

  ** Log for this instance.
  internal Log? log := null
}

**************************************************************************
** ModbusTcpClient
**************************************************************************

@NoDoc
class ModbusTcpTransport : ModbusTransport
{
  ** Construct new TCP transport.
  new make(IpAddr host, Int? port, Duration timeout)
  {
    this.host  = host
    this.port  = port ?: 502
    this.socketConfig = SocketConfig.cur.setTimeouts(timeout)
  }

  ** Host for this client.
  const IpAddr host

  ** Port number for this client.
  const Int port

  ** SocketConfig for TCP socket.
  const SocketConfig socketConfig

  override Bool useCrc() { false }

  override Void open()
  {
    if (socket?.isConnected == true) return
    socket = TcpSocket(this.socketConfig)
    socket.connect(host, port)
  }

  override Void close()
  {
    socket?.close
    socket = null
  }

  override ModbusInStream req(Buf msg)
  {
    if (socket == null || !socket.isConnected)
      throw IOErr("Socket not open")

    // handle txId overflow
    reqTxId := txId++
    if (txId > 0xffff) txId = 0

    if (log?.isDebug == true)
    {
      s := StrBuf()
        .add("> $reqTxId\n")
        .add("Modbus Req\n")
        .add(reqTxId.toHex(4)).add(" ")
        .add(0.toHex(4)).add(" ")
        .add(msg.size.toHex(4)).add(" ")
        .add(msg.toHex)
      log.debug(s.toStr)
    }

    // send req
    out := socket.out
    out.writeI2(reqTxId)     // req tx id
    out.writeI2(0)           // always 0x0000
    out.writeI2(msg.size)    // msg length
    out.writeBuf(msg.flip)   // msg
    out.flush

    // verify transactionIds
    in := ModbusInStream(socket.in, log, "$reqTxId")
    resTxId := in.readU2
    if (reqTxId != resTxId) throw IOErr("Transaction ID mistmatch $reqTxId != $resTxId")

    // read framing off
    in.readU2         // always 0x0000
    len := in.readU2  // res len

    return in
  }

  private TcpSocket? socket
  private Int txId := 0
}

**************************************************************************
** ModbusRtuTcpTransport
**************************************************************************

@NoDoc
class ModbusRtuTcpTransport : ModbusTransport
{
  ** Construct new TCP transport.
  new make(IpAddr host, Int? port, Duration timeout)
  {
    this.host  = host
    this.port  = port ?: 502
    this.socketConfig = SocketConfig.cur.copy {
      it.connectTimeout = timeout
      it.receiveTimeout = timeout
    }
  }

  ** Host for this client.
  const IpAddr host

  ** Port number for this client.
  const Int port

  ** SocketConfig for TCP socket.
  const SocketConfig socketConfig

  override Void open()
  {
    if (socket?.isConnected == true) return
    socket = TcpSocket(this.socketConfig)
    socket.connect(host, port)
  }

  override Void close()
  {
    socket?.close
    socket = null
  }

  override ModbusInStream req(Buf msg)
  {
    if (socket == null || !socket.isConnected) throw IOErr("Socket not open")
    if (log?.isDebug == true)
    {
      log.debug("> RTU-TCP\nModbus Req\n${msg.toHex}")
    }
    socket.out.writeBuf(msg.flip).flush
    return ModbusInStream(socket.in, log, "RTU-TCP")
  }

  private TcpSocket? socket
}

**************************************************************************
** ModbusRtuTransport
**************************************************************************

@NoDoc
class ModbusRtuTransport : ModbusTransport
{
  ** Construct a new RTU transport.
  new make(SerialSocket port, Duration frameDelay := 50ms)
  {
    if (frameDelay < 2ms)
      throw IOErr("frameDelay out of bounds $frameDelay < 2ms")

    this.port = port
    this.port.timeout = null
    this.frameDelay = frameDelay
  }

  override Void open() {}    // SerialMx handles open/close

  override Void close()
  {
    port.close
  }

  override ModbusInStream req(Buf msg)
  {
    // trace outgoing message
    if (log?.isDebug == true)
    {
      log.debug("> RTU\nModbus Req\n$msg.toHex")
    }

    // write msg
    port.out.writeBuf(msg.flip).flush
    Actor.sleep(frameDelay)

    // read frame
    try
    {
      start := Duration.now
      buf   := Buf()
      while (true)
      {
        now := Duration.now
        if (port.in.avail == 0)
        {
          if (buf.size > 0 && now - start > frameDelay) break
          if (now - start > timeout) throw IOErr("Response timeout")
          Actor.sleep(1ms)
          continue
        }

        byte := port.in.read
        if (byte != null) buf.write(byte)
        start = now
      }

      // return resp
      return ModbusInStream(buf.flip.in, log, "RTU")
    }
    finally { Actor.sleep(frameDelay) }
  }

  private SerialSocket port
  private const Duration frameDelay
  private const Duration timeout := 1sec
}

**************************************************************************
** ModbusInStream
**************************************************************************

@NoDoc
class ModbusInStream : InStream
{
  new make(InStream? in, Log? log, Str label := "") : super(in)
  {
    this.log     = log
    this.label   = label
  }

  private Log? log
  private const Str label
  Buf data := Buf() { private set }

  override Int? read()
  {
    b := super.read
    if (b != null) data.write(b)
    return b
  }

  override Int? readBuf(Buf buf, Int n)
  {
    p := buf.pos
    c := super.readBuf(buf, n)
    if (c != null) data.writeBuf(buf[p..<(p+c)])
    return c
  }

  override This unread(Int b) { throw IOErr("unread not supported") }

  // Do not close underlying InStream since it is the actual socket or port to the device
  override Bool close()
  {
    if (log?.isDebug ?: false)
    {
      s := StrBuf()
        .add("< $label\n")
        .add("Modbus Res\n")
        .add(data.toHex)
      log.debug(s.toStr())
      data.clear
    }
    return true
  }

}
