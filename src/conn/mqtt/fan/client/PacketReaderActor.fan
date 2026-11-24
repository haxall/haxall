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
    if (log.isDebug) log.debug(packet.trace("<", buf))

    // dispatch
    client.packetReceived(packet)

    // do not keep a buffer which grew for a large packet
    if (buf.capacity > maxBufReuse) Actor.locals.remove("buf")

    return true
  }
}
