//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  06 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**
** Reads incoming packets from the transport layer and dispatches them.
**
internal const class PacketReaderActor : Actor, DataCodec
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MqttClient client) : super(client.config.pool)
  {
    this.client = client
  }

  private const MqttClient client

  ** The read buffer is only reused up to this capacity, so that
  ** one large packet does not hold its memory for the life of the client
  private static const Int maxBufReuse := 256 * 1024

  private Log log() { client.log }

//////////////////////////////////////////////////////////////////////////
// Actor
//////////////////////////////////////////////////////////////////////////

  ** The message is the transport to read from wrapped as Unsafe
  protected override Obj? receive(Obj? obj)
  {
    try
    {
      // if receive failed exit receive loop
      if (!doReceive(((Unsafe)obj).val)) return null
    }
    catch (Err err)
    {
      // if client can no longer message exit receive loop
      if (!client.canMessage) return null
      log.err("Packet.read", err)
    }

    send(obj)
    return null
  }

  private Bool doReceive(MqttTransport transport)
  {
    // allocate reusable buffer
    buf := Actor.locals["buf"] as Buf
    if (buf == null) Actor.locals["buf"] = buf = Buf(4096)
    buf.clear

    // read raw buf from transport
    try
    {
      in := transport.in

      // fixed header
      byte1 := in.read ?: throw IOErr("Connection closed by broker")
      len   := readVbi(in)

      // the AUTH exchange of enhanced authentication is not implemented
      if (byte1.shiftr(4) == PacketType.auth.ordinal) throw MqttErr("Enhanced authentication is not supported")

      // do not buffer a packet which is larger than the client accepts
      max := (client.lastConnectConfig.val as ConnectConfig)?.maxPacketSize
      if (max != null && toPacketSize(len) > max) { skip(in, byte1, len); return true }

      writeByte(byte1, buf)
      writeVbi(len, buf)

      // variable header + payload (do not close input stream!!!)
      in.pipe(buf.out, len, false)
      buf.seek(0)
    }
    catch (Err err)
    {
      // the transport is no longer usable so exit the receive loop; shutdown
      // the client unless it closed or replaced the transport already
      if (transport === client.transport && !transport.isClosed) client.shutdown(err)
      return false
    }

    // decode the control packet
    packet := ControlPacket.readPacket(buf.in, client.config.version)

    // trace
    if (log.isDebug) log.debug(packet.trace("<", buf))

    // dispatch
    client.packetReceived(packet)

    // do not keep a buffer which grew for a large packet
    if (buf.capacity > maxBufReuse) Actor.locals.remove("buf")

    return true
  }

  ** Discard a packet which is larger than the client accepts without
  ** buffering it. A PUBLISH is acknowledged so that the server does not
  ** send it again, and is counted as a delivery error. Any other packet
  ** of that size is an error which closes the connection.
  private Void skip(InStream in, Int byte1, Int len)
  {
    size := toPacketSize(len)
    type := PacketType.vals[byte1.shiftr(4)]
    if (type !== PacketType.publish) throw MqttErr("Packet exceeds max packet size: ${type} ${size} bytes")

    // read the topic name and packet identifier, then discard the rest
    qos      := byte1.shiftr(1).and(0x03)
    topicLen := in.readU2
    topic    := in.readBufFully(null, topicLen).readAllStr
    pid      := qos > 0 ? in.readU2 : 0
    rest     := len - 2 - topicLen - (qos > 0 ? 2 : 0)
    if (rest < 0) throw MqttErr("Malformed publish packet")
    chunk := Buf(8192)
    while (rest > 0)
    {
      n := in.readBuf(chunk.clear, rest.min(8192)) ?: throw IOErr("Connection closed by broker")
      rest -= n
    }

    client.lastPacketReceived.val = Duration.nowTicks
    client.deliveryErr("Publish to ${topic} exceeds max packet size: ${size} bytes")
    if (qos == 0) return

    // 5.0 can tell the server that the message was not accepted
    reason := client.config.version.is5 ? ReasonCode.implementation_specific_error : ReasonCode.success
    ControlPacket? ack
    if (qos == 1) ack = PubAck(pid) { it.reason = reason }
    else ack = PubRec(pid) { it.reason = reason }
    client.packetWriter.send(ack)
  }

  ** Size of a packet given the remaining length in its fixed header
  private static Int toPacketSize(Int len)
  {
    if (len < 128) return len + 2
    if (len < 16_384) return len + 3
    if (len < 2_097_152) return len + 4
    return len + 5
  }
}
