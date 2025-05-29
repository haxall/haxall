//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  04 May 2021   Matthew Giannini  Creation
//

using concurrent

**
** Utility to build a publish request and then send it.
**
final class PubSend
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  internal new make(MqttClient client)
  {
    this.client = client
    qos(QoS.two)
    payload(Buf(0))
  }

  private const MqttClient client

  private Str? _topic := null

  private [Field:Obj?] fields := [:]

  private StrPair[] userProps := [,]

//////////////////////////////////////////////////////////////////////////
// Builder
//////////////////////////////////////////////////////////////////////////

  ** Set the topic to publish to.
  This topic(Str topic)
  {
    this._topic = Topic.validateName(topic)
    return this
  }

  ** Set the payload to send.
  This payload(Buf payload)
  {
    fields[Message#payload] = payload.toImmutable
    return this
  }

  ** Publish this message with QoS 0
  This qos0() { qos(QoS.zero) }

  ** Publish this message with QoS 1
  This qos1() { qos(QoS.one) }

  ** Publish this message with QoS 2
  This qos2() { qos(QoS.two) }

  ** Publish this message with the given quality-of-service
  ** 'qos' may be either `QoS` or an Int.
  This qos(Obj qos)
  {
    if (qos is Int) qos = QoS.vals[(Int)qos]
    else if (qos isnot QoS) throw ArgErr("Cannot set QoS from ${qos} ($qos.typeof)")
    fields[Message#qos] = qos
    return this
  }

  ** Should the message be retained?
  This retain(Bool retain)
  {
    fields[Message#retain] = retain
    return this
  }

  ** Notify the recepient that the payload is UTF-8 encoded data.
  ** (**MQTT 5 only**)
  This utf8Payload(Bool isUtf8)
  {
    fields[Message#utf8Payload] = isUtf8
    return this
  }

  ** Set the expiry interval for the message
  ** (**MQTT 5 only**)
  This expiryInterval(Duration? interval)
  {
    fields[Message#expiryInterval] = interval
    return this
  }

  ** Add user properties to send with the publish. This method
  ** may be called more than once to add multiple user properties
  ** (**MQTT 5 only**)
  This addUserProps(Str:Str props)
  {
    props.each |Str name, Str value| {userProp(name, value)}
    return this
  }

  ** Add a user property to send with the publish. This method
  ** may be called more than once to add multiple user properties
  ** (**MQTT 5 only**)
  This userProp(Str name, Str value)
  {
    userProps.add(StrPair(name, value))
    return this
  }

  ** Set the content type for the payload of this message.
  ** (**MQTT 5 only**)
  This contentType(Str contentType)
  {
    fields[Message#contentType] = contentType
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Send
//////////////////////////////////////////////////////////////////////////

  ** Build and send the publish packet. A future is returned that will be
  ** completed when the acknowledgement is received according to the
  ** configure quality-of-service.
  Future send()
  {
    if (this._topic == null) throw ArgErr("No topic configured")

    fields[Message#userProps] = this.userProps.toImmutable
    setter := Field.makeSetFunc(this.fields)
    msg    := Message#.make([setter])

    return client.publish(this._topic, msg)
  }
}