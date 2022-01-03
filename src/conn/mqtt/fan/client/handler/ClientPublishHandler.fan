//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  13 Apr 2021   Matthew Giannini  Creation
//

using concurrent

internal class ClientPublishHandler : ClientHandler
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MqttClient client) : super(client)
  {
  }

  private static const Str pub_prefix    := "p1-"
  private static const Str pubrec_prefix := "p2-"
  private static const Str pubrel_prefix := "p3-"

//////////////////////////////////////////////////////////////////////////
// Publish Sender Flow
//////////////////////////////////////////////////////////////////////////

  Future publish(Publish packet)
  {
    client.checkCanMessage

    // check max QoS specified by the server [MQTT5-3.2.2-11]
    if (packet.qos > connackProps.maxQoS)
    {
      return reject("Max. QoS on server is ${connackProps.maxQoS}. Cannot send ${packet.qos}")
    }

    // check retain available [MQTT5-3.2.2-14]
    if (packet.retain && !connackProps.retainAvailable)
    {
      return reject("Retained messages not supported by the server")
    }

    // a PUBLISH packet sent from a client to a server MUST NOT contain
    // a subscription identifier [MQTT5-3.3.4-6]
    if (packet.msg.props[Property.subscriptionId] != null)
    {
      return reject("A publish packet sent to a server must not contain a subscription identifier: $packet.msg.props")
    }

    // QoS 0 - fire and forget
    if (packet.qos.isZero)
    {
      return client.packetWriter.sendSync(packet)
    }

    // check quota
    // TODO:ENHANCE - maybe add packet buffering if in-flight window is full
    serverQuota := connackProps.receiveMax
    if (client.quota.val == 0)
    {
      return reject("Quota exceeded: ${serverQuota}")
    }

    // the packet will be persisted using this version
    packet.packetVersionRef.val = this.version

    // we can send immediately
    try
    {
      // assign packet identifer
      packet.packetId.val = client.nextPacketId

      // store the packet
      key := pubKey(packet)
      db.put(key, packet)

      // send it
      pending := client.sendPacket(packet, PendingAck(packet, key))

      // update quota
      client.quota.decrement

      return pending.resp
    }
    catch (Err err)
    {
      log.err("Failed to send QoS packet", err)
      throw err
    }
  }

  private static Future reject(Str reason)
  {
    Future.makeCompletable.completeErr(MqttErr(reason))
  }

  private static MqttErr toErr(PubFlowPacket packet)
  {
    details := packet.props.reasonStr ?: "No details available."
    return MqttErr("Publish failed: ${packet.reason}. Details: $details")
  }

  ** Handle an incoming PUBACK for a QoS 1 message that we sent
  Void pubAck(PubAck packet, PendingAck pending)
  {
    onFinalAck(packet, pending)
  }

  ** Handle an incoming PUBREC packet for a QoS 2 message that we sent
  Void pubRec(PubRec packet, PendingAck pending)
  {
    // discard the original publish message
    key := pubKey(packet)
    db.remove(key)

    // the sender MUST send a PUBREL packet when it receives a PUBREC packet from the
    // receiver with a Reason Code less than 0x80 [MQTT5-4.3.3-4]
    //
    // I think this is a correct interpretation of the spec:
    // short-circuit if the pubrec is an error
    if (packet.isErr) return pending.resp.completeErr(toErr(packet))

    // store the PUBREL message ack
    ack := PubRel(packet.pid)
    key = pubrelKey(ack)
    db.put(key, ack)

    // send it - this is a 2-phase ack so clone the pending future
    // but with its new persistence key. The original sender will
    // not be notified that the publish is complete until a PUBCOMP
    // is received
    client.sendPacket(ack, PendingAck.clone(pending, key))
  }

  ** Handle an incoming PUBCOMP packet for a QoS 2 message that we sent
  Void pubComp(PubComp packet, PendingAck pending)
  {
    onFinalAck(packet, pending)
  }

  private Void onFinalAck(PubFlowPacket packet, PendingAck pending)
  {
    // discard state
    db.remove(pending.persistKey)

    // update quota
    client.quota.increment

    // check for an error code
    if (packet.isErr) pending.resp.completeErr(toErr(packet))
  }

//////////////////////////////////////////////////////////////////////////
// PUBLISH Receiver Flow
//////////////////////////////////////////////////////////////////////////

  ** Handle an incoming PUBLISH packet from the server
  Obj? deliver(Publish packet)
  {
    if (packet.qos === QoS.zero)
    {
      client.subMgr.deliver(packet)
    }
    else if (packet.qos === QoS.one)
    {
      client.subMgr.deliver(packet)
      client.packetWriter.send(PubAck(packet.pid))
    }
    else if (packet.qos === QoS.two)
    {
      ack := PubRec(packet.pid)
      key := pubrecKey(packet)

      // only store and deliver the packet if this is the first time
      // we've seen it.
      if (!db.containsKey(key))
      {
        db.put(key, ack)
        client.subMgr.deliver(packet)
      }

      // always ack
      client.packetWriter.send(ack)
    }
    return null
  }

  ** Handle a QoS 2 PUBREL packet from the server
  **
  ** Pre-Condition: We have already delievered the original PUBLISH
  ** packet to the application.
  Obj? pubRel(PubRel packet)
  {
    ack := PubComp(packet.pid)

    // discard stored state
    key := pubrecKey(packet)
    db.remove(key)

    // always respond with ack
    client.packetWriter.send(ack)

    return null
  }

//////////////////////////////////////////////////////////////////////////
// Resume
//////////////////////////////////////////////////////////////////////////

  Void resume()
  {
    // [MQTT-4.4.0-1] - When a client reconnects with CleanSession set to 0, bot the client
    // and the server MUST re-send any unacknowledged PUBLISH packets (where QoS > 0)
    // and PUBREL packets using their original packet identifiers.
    db.each |p, key|
    {
      if (key.startsWith(pub_prefix) || key.startsWith(pubrel_prefix))
      {
        try
        {
          packet := (PersistableControlPacket)ControlPacket.readPacket(p.in, p.packetVersion)
          // log.info("Resend unacknowledged packet: $packet [$key]")

          // mark that we are sending a duplicate packet
          packet.markDup
          client.sendPacket(packet, PendingAck(packet, key))
        }
        catch (Err err)
        {
          log.err("Failed to resend packet: ${key}", err)
        }
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  private static Str pubKey(ControlPacket packet) { "${pub_prefix}${packet.pid}" }

  private static Str pubrelKey(ControlPacket packet) { "${pubrel_prefix}${packet.pid}" }

  private static Str pubrecKey(ControlPacket packet) { "${pubrec_prefix}${packet.pid}" }
}