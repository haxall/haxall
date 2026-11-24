//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  23 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**************************************************************************
** ClientSubMgr
**************************************************************************

internal class ClientSubMgr : ClientHandler
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MqttClient client) : super(client)
  {
  }

  ** Map topic filters to their listeners
  private [Str:SubscriptionListener] topics := [:]

  ** Map topic alises to their topic. This map is for incoming
  ** PUBLISH requests only.
  private [Int:Str] aliases := [:]

  ** Do any cleanup when a network connection is closed
  Void close()
  {
    // A receiver must not carry forward any topic alias mappings from
    // on network connection to another [MQTT5-3.3.2-7]
    aliases.clear
  }

  ** Do any cleanup when the session is ended
  Void clear()
  {
    topics.clear
  }

//////////////////////////////////////////////////////////////////////////
// Subscribe
//////////////////////////////////////////////////////////////////////////

  Future subscribe(Subscribe packet, SubscriptionListener listener)
  {
    client.checkCanMessage

    // assign a packet identifier
    packet.packetId.val = client.nextPacketId

    // go ahead and map the filters because the server is allowed to send
    // PUBLISH packets to the client *before* it sends the SUBACK
    //
    // only one listener can be registered for a topic (so we overwrite any
    // previously registered listeners)
    packet.topics.each |topic| { topics[topic] = listener }

    // send packet
    return client.sendPacket(packet, PendingAck(packet)).resp
  }

  Void subAck(SubAck ack, PendingAck pending)
  {
    // notify listeners about the subscription status
    subscribe := (Subscribe)pending.req
    ReasonCode? failed
    subscribe.topics.each |topic, i|
    {
      reason := ack.returnCodes.getSafe(i) ?: ReasonCode.unspecified_error
      if (reason.isErr) failed = reason
      try
        topics[topic]?.onSubscribed(topic, reason, ack.props)
      catch (Err err)
        log.err("onSubscribed callback failed", err)
    }

    // the server did not make the subscription
    if (failed != null) pending.resp.completeErr(MqttErr.makeReason(failed, null, ack.props.reasonStr))
  }

//////////////////////////////////////////////////////////////////////////
// Deliver
//////////////////////////////////////////////////////////////////////////

  ** Deliver this message to all subscribed listeners. This method
  ** is guaranteed to never throw an Err. The message is considered
  ** completely delivered when this method completes.
  Void deliver(Publish packet)
  {
    // handle topic alias
    topicName := packet.topicName
    alias     := packet.msg.topicAlias
    if (alias != null)
    {
      if (topicName.isEmpty) topicName = aliases[alias] ?: ""
      else aliases[alias] = topicName
    }
    if (topicName.isEmpty) { client.deliveryErr("Publish has no topic name or known topic alias: ${alias}"); return }

    try
      clientConfig.onMessage?.call(topicName, packet.msg)
    catch (Err err)
      client.deliveryErr("Delivery of ${topicName} failed", err)

    topics.each |listener, filter|
    {
      try
      {
        if (!Topic.matches(topicName, filter)) return
        listener.onMessage(topicName, packet.msg)
      }
      catch (Err err)
      {
        client.deliveryErr("Delivery of ${topicName} to ${filter} failed", err)
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Unsubscribe
//////////////////////////////////////////////////////////////////////////

  Future unsubscribe(Unsubscribe packet)
  {
    client.checkCanMessage

    // assign a packet identifier
    packet.packetId.val = client.nextPacketId

    // do not remove listener until ack is received

    // send packet
    return client.sendPacket(packet, PendingAck(packet)).resp
  }

  Void unsubAck(UnsubAck ack, PendingAck pending)
  {
    unsub := (Unsubscribe)pending.req
    unsub.topics.each |topic, i|
    {
      reason := ack.reasons.getSafe(i) ?: ReasonCode.success

      // remove from subscription state and notify listener
      this.topics.remove(topic)?.onUnsubscribed(topic, reason, ack.props)
    }
  }
}

**************************************************************************
** SubscriptionListener
**************************************************************************

**
** A subscription listener receives callbacks related to a topic subscription.
**
mixin SubscriptionListener
{
  ** Callback when the subscription is acknowledged. The [ReasonCode] indicates
  ** if the subscription was a success or not.
  virtual Void onSubscribed(Str topic, ReasonCode reason, Properties props) { }

  ** Callback when a message is received on the given topic.
  virtual Void onMessage(Str topic, Message msg) { }

  ** Callback when the unsubscribe is acknowledged.
  virtual Void onUnsubscribed(Str topic, ReasonCode reason, Properties props) { }
}
