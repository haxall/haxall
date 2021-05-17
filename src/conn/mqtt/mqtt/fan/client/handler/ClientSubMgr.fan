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

    try
    {
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
    catch (Err err)
    {
      log.err("Failed to send subscribe packet", err)
      throw err
    }
  }

  Void subAck(SubAck ack, PendingAck pending)
  {
    // notify listeners about the subscription status
    subscribe := (Subscribe)pending.req
    subscribe.topics.each |topic, i|
    {
      try
        topics[topic]?.onSubscribed(topic, ack.returnCodes[i], ack.props)
      catch (Err err)
        log.err("onSubscribed callback failed", err)
    }
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

    topics.each |listener, filter|
    {
      try
      {
        if (!Topic.matches(topicName, filter)) return
        listener.onMessage(packet.topicName, packet.msg)
      }
      catch (Err err)
      {
        log.err("Delivery of $packet.topicName to $filter failed", err)
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Unsubscribe
//////////////////////////////////////////////////////////////////////////

  Future unsubscribe(Unsubscribe packet)
  {
    client.checkCanMessage

    try
    {
      // assign a packet identifier
      packet.packetId.val = client.nextPacketId

      // do not remove listener until ack is received

      // send packet
      return client.sendPacket(packet, PendingAck(packet)).resp
    }
    catch (Err err)
    {
      log.err("Failed to unsubscribe", err)
      throw err
    }
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
** ClientSubscription
**************************************************************************

// internal class ClientSubscription
// {
//   new make(Subscribe packet, SubscriptionListener listener)
//   {
//     this.packet   = packet
//     this.listener = listener
//   }

//   const Subscribe packet
//   SubscriptionListener listener { private set }
// }

// internal const class ClientSubscription_1
// {
//   new make(Str topicFilter, Int? id := null)
//   {
//     this.topicFilter = topicFilter
//     this. id = id ?: 0
//   }

//   const Str topicFilter
//   const Int id

//   override Int hash()
//   {
//     res := 31
//     res = (31 * res) + topicFilter.hash
//     res = (31 * res) + id
//     return res
//   }

//   overrid Bool equals(Obj? obj)
//   {
//     if (this === obj) return true
//     that := obj as ClientSubscription
//     if (that == null )return false
//     if (this.topicFilter != that.topicFilter) return false
//     if (this.id != that.id) return false
//     return true
//   }
// }

**************************************************************************
** SubscriptionListener
**************************************************************************

mixin SubscriptionListener
{
  virtual Void onSubscribed(Str topic, ReasonCode reason, Properties props) { }

  virtual Void onMessage(Str topic, Message msg) { }

  virtual Void onUnsubscribed(Str topic, ReasonCode reason, Properties props) { }
}