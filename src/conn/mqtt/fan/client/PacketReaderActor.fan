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
      writeByte(in.read ?: throw IOErr("Connection closed by broker"), buf)
      len := readVbi(in)
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
    payload := false
    switch (packet.type)
    {
      case PacketType.publish:
        s.add(" ${packet->topicName} qos=${packet->qos}")
        payload = true
    }
    s.addChar('\n')
    s.add(buf.toHex)
    if (payload)
    {
      try
      {
        payloadStr := packet->payload->in->readAllStr
        s.add("\n\nPayload:\n$payloadStr")
      }
      catch (Err ignore) { /* not utf-8 encoded string */ }
    }
    client.log.debug(s.toStr)
  }
}
