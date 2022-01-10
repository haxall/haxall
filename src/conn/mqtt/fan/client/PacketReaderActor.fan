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

  private Log log() { client.log }
  private MqttTransport? transport() { client.transport }

//////////////////////////////////////////////////////////////////////////
// Actor
//////////////////////////////////////////////////////////////////////////

  protected override Obj? receive(Obj? obj)
  {
    try
    {
      // if receive failed exit receive loop
      if (!doReceive) return null
    }
    catch (Err err)
    {
      // if client can no longer message exit receive loop
      if (!client.canMessage) return null
      log.err("Packet.read", err)
    }

    send("loop")
    return null
  }

  private Bool doReceive()
  {
    // allocate reusable buffer
    buf := Actor.locals["buf"] as Buf
    if (buf == null) Actor.locals["buf"] = buf = Buf(4096)
    buf.clear

    // read raw buf from transport, on error shutdown the client
    try
    {
      in := transport.in

      // fixed header
      writeByte(readByte(in), buf)
      len := readVbi(in)
      writeVbi(len, buf)

      // variable header + payload (do not close input stream!!!)
      in.pipe(buf.out, len, false)
      buf.seek(0)
    }
    catch (Err err)
    {
      if (transport?.isClosed ?: true) return false
      throw client.shutdown(err)
    }

    // decode the control packet
    packet := ControlPacket.readPacket(buf.in, client.config.version)

    // trace
    trace(packet, buf)

    // dispatch
    client.packetReceived(packet)

    return true
  }

  private Void trace(ControlPacket packet, Buf buf)
  {
    if (!client.log.isDebug) return

    s := StrBuf().add("< $packet.pid\n")
    s.add("Packet Type: $packet.type")
    switch (packet.type)
    {
      case PacketType.publish:
        s.add(" ${packet->topicName} qos=${packet->qos}")
    }
    s.addChar('\n')
    s.add(buf.toHex)
    client.log.debug(s.toStr)
  }
}
