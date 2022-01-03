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
internal const class PacketWriterActor : Actor, DataCodec
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MqttClient client) : super(client.pool)
  {
    this.client  = client
    this.version = client.config.version
  }

  private const MqttClient client
  private const MqttVersion version
  private MqttTransport transport() { client.transport }

  ** Blocking send. Do not return until this packet has been sent over the network.
  Future sendSync(ControlPacket packet)
  {
    f := send(packet)
    try { f.get } catch (Err ignore) { }
    return f
  }

//////////////////////////////////////////////////////////////////////////
// Actor
//////////////////////////////////////////////////////////////////////////

  protected override Obj? receive(Obj? obj)
  {
    packet := obj as ControlPacket
    if (packet == null) throw MqttErr("Not a control packet: $obj (${obj?.typeof})")

    // allocate reusable buf
    buf := Actor.locals["buf"] as Buf
    if (buf == null) Actor.locals["buf"] = buf = Buf(4096)
    buf.clear

    try
    {
      packet.encode(buf.out, version)
      transport.send(buf.flip)

      client.lastPacketSent.val = Duration.nowTicks
    }
    catch (Err err)
    {
      client.log.err("Failed to write packet $packet.type", err)
    }

    return packet
  }
}