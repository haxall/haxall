//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  09 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**
** Writes outgoing packets to the transport layer.
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

  ** Send the packet async.
  Future send(ControlPacket packet)
  {
    // encode before sending to actor so that calling thread immediately
    // gets notified of an encoding error
    buf := Buf(4096)
    packet.encode(buf.out, version)

    // the client must not send a packet larger than the server accepts [MQTT5-3.2.2-15]
    max := client.serverMaxPacketSize
    if (max != null && buf.size > max)
      throw MqttErr("Packet exceeds server max packet size of ${max}: ${packet.type} ${buf.size} bytes")

    return actor.send(ActorMsg("send", packet, buf.flip.toImmutable))
  }

//////////////////////////////////////////////////////////////////////////
// Actor
//////////////////////////////////////////////////////////////////////////

  private Obj? onSend(ActorMsg msg)
  {
    packet := msg.a as ControlPacket
    buf    := msg.b as Buf

    // packets still queued after a disconnect just fail
    transport := client.transport ?: throw IOErr("Not connected")

    try
    {
      // trace
      if (client.log.isDebug) client.log.debug(packet.trace(">", buf))

      transport.send(buf)

      client.lastPacketSent.val = Duration.nowTicks
    }
    catch (IOErr err)
    {
      client.shutdown(err)
      throw err
    }
    catch (Err err)
    {
      client.log.err("Failed to write packet $packet.type", err)
      throw err
    }

    return packet
  }
}
