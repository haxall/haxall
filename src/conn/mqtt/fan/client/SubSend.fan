//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  04 May 2021   Matthew Giannini  Creation
//

using concurrent

**************************************************************************
** SubSend
**************************************************************************

**
** Utility to build a subscribe request for a single topic and then send it.
**
** By default, the following settings are enabled:
** - QoS 2
** - No Local is disabled (false)
** - Retain as Published is turned off (false)
** - Retain Handling is set to 'send'
final class SubSend
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  internal new make(MqttClient client)
  {
    this.client = client
  }

  private const MqttClient client

  private Str? _topicFilter := null

  private QoS _qos := QoS.two

  private Bool _noLocal := false

  private Bool _retainAsPublished := false

  private RetainHandling _retainHandling := RetainHandling.send

  private CallbackListener callbacks := CallbackListener()

//////////////////////////////////////////////////////////////////////////
// Builder
//////////////////////////////////////////////////////////////////////////

  ** Set the topic filter to subscribe to. You must set a topic filter
  ** before you call `send`.
  This topicFilter(Str topicFilter)
  {
    this._topicFilter = Topic.validateFilter(topicFilter)
    return this
  }

  ** Request maximum QoS 0
  This qos0() { qos(QoS.zero) }

  ** Request maximum QoS 1
  This qos1() { qos(QoS.one) }

  ** Request maximum QoS 2
  This qos2() { qos(QoS.two) }

  ** Request maximum QoS
  This qos(QoS qos)
  {
    this._qos = qos
    return this
  }

  ** If true, application messages will not be forwareded to a connection
  ** with a clientID equal to the clientID of the publishing connection.
  ** Cannot be set on a shared subscription.
  ** (**MQTT 5 only**)
  This noLocal(Bool val)
  {
    this._noLocal = val
    return this
  }

  ** If true, application messages forwared using this subscription keep the RETAIN
  ** flag they were published with. If false, application messages forwarded using this
  ** subscription have the RETAIN flag set to 0 (false).
  ** (**MQTT 5 only**)
  This retainAsPublished(Bool val)
  {
    this._retainAsPublished = val
    return this
  }

  ** This option specifies whether retained are sent when the subscription is
  ** established.
  ** (**MQTT 5 only**)
  This retainHandling(RetainHandling val)
  {
    this._retainHandling = val
    return this
  }

  ** Set the callback to be invoked when the subscription is acknowledged.
  This onSubscribe(|Str topic, ReasonCode reason, Properties props| cb)
  {
    this.callbacks.cbSub = cb
    return this
  }

  ** Set the callback to be invoked when a message is published to this subscription.
  This onMessage(|Str topic, Message msg| cb)
  {
    this.callbacks.cbMsg = cb
    return this
  }

  ** Set the callback to be invoked after the subscription is unsubscribed.
  This onUnsubscribe(|Str topic, ReasonCode reason, Properties props| cb)
  {
    this.callbacks.cbUnsub = cb
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Send
//////////////////////////////////////////////////////////////////////////

  ** Build and send the subscribe packet. A future is returned that will be
  ** completed when the 'SUBACK' is received.
  Future send()
  {
    if (_topicFilter == null) throw ArgErr("Topic filter not set")
    return client.subscribe(_topicFilter, buildOpts, callbacks)
  }

  private Int buildOpts()
  {
    opts := _qos.ordinal
    if (client.config.version.is5)
    {
      if (_noLocal)           opts = opts.or(0b0000_0100)
      if (_retainAsPublished) opts = opts.or(0b0000_1000)
      opts = opts.or(_retainHandling.ordinal.shiftl(4))
    }
    return opts
  }
}

**************************************************************************
** RetainHandling
**************************************************************************

enum class RetainHandling
{
  ** send retained messages at the time of the subscribe
  send,
  ** send retained messages at subscribe only if they subscription does not currently exists
  send_only_if_new_subscription,
  ** do not send retained messages at the time of the subscribe
  do_not_send
}

**************************************************************************
** CallbackListener
**************************************************************************

internal class CallbackListener : SubscriptionListener
{
  |Str,ReasonCode,Properties|? cbSub := null
  |Str,Message|? cbMsg := null
  |Str,ReasonCode,Properties|? cbUnsub := null

  override Void onSubscribed(Str topic, ReasonCode reason, Properties props)
  {
    cbSub?.call(topic, reason, props)
  }

  override Void onMessage(Str topic, Message msg)
  {
    cbMsg?.call(topic, msg)
  }

  override Void onUnsubscribed(Str topic, ReasonCode reason, Properties props)
  {
    cbUnsub?.call(topic, reason, props)
  }
}