//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  09 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**
** Reads incoming packets from the transport layer and dispatches
** them back to the client.
**
internal const class PacketWriterActor : DataCodec
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MqttClient client)
  {
    this.client  = client
    this.version = client.config.version
    this.actor   = Actor(client.pool) |msg->Obj?| { onSend(msg) }
  }

  private const MqttClient client
  private const MqttVersion version
  private const Actor actor
  private MqttTransport transport() { client.transport }

  ** Blocking send. Do not return until this packet has been sent over the network.
  Future sendSync(ControlPacket packet)
  {
    f := send(packet)
    try { f.get } catch (Err ignore) { }
    return f
  }

  ** Send the packet async.
  Future send(ControlPacket packet)
  {
    // encode before sending to actor so that calling thread immediately
    // gets notified of an encoding error
    buf := Buf(4096)
    packet.encode(buf.out, version)
    return actor.send(ActorMsg("send", packet, buf.flip.toImmutable))
  }

//////////////////////////////////////////////////////////////////////////
// Actor
//////////////////////////////////////////////////////////////////////////

  private Obj? onSend(ActorMsg msg)
  {
    packet := msg.a as ControlPacket
    buf    := msg.b as Buf

    try
    {
      transport.send(buf)

      client.lastPacketSent.val = Duration.nowTicks

      // trace
      trace(packet, buf)
    }
    catch (Err err)
    {
      client.log.err("Failed to write packet $packet.type", err)
    }

    return packet
  }

  private Void trace(ControlPacket packet, Buf buf)
  {
    if (!client.log.isDebug) return

    s := StrBuf().add("> $packet.pid\n")
    s.add("Packet Type: $packet.type")
    payload := false
    switch (packet.type)
    {
      case PacketType.publish:
        s.add(" topic=${packet->topicName} qos=${packet->qos}")
        payload = true
      case PacketType.subscribe:
        opts := ((Int[])packet->opts).map |i->Str| { i.toRadix(2, 8) }
        s.add(" topics=${packet->topics} ${opts}")
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