//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   03 Jan 2022  Matthew Giannini  Creation
//

using xeto
using haystack
using hx
using hxd
using hxConn
using obs
using mqtt

**
** MQTT connector library
**
const class MqttExt : ConnExt
{
  static MqttExt? cur(Bool checked := true)
  {
    Context.cur.ext("hx.mqtt", checked)
  }

  internal const MqttObservable mqtt := MqttObservable(this)

  const override Observable[] observables := [mqtt]

  override Str onConnDetails(Conn conn)
  {
    conn.data ?: "<no additional details>"
  }
}

**************************************************************************
** MqttObservable
**************************************************************************

internal const class MqttObservable : Observable
{
  new make(MqttExt ext) { this.ext = ext }

  const MqttExt ext

  override Str name() { "obsMqtt" }

  protected override Subscription onSubscribe(Observer observer, Dict config)
  {
    connRef := config["obsMqttConnRef"] as Ref ?: throw Err("obsMqttConnRef not configured")
    Topic.validateFilter(config["obsMqttTopic"] as Str ?: throw Err("obsMqttTopic not configured"))
    conn    := ext.conn(connRef)
    sub     := MqttSubscription(this, observer, config)
    // subscribe async
    conn.send(HxMsg("mqtt.sub", sub))
    return sub
  }

  protected override Void onUnsubscribe(Subscription s)
  {
    sub  := (MqttSubscription)s
    conn := ext.conn(sub.connRef, false)
    if (conn == null) return
    // unsubscribe async
    try
      conn.send(HxMsg("mqtt.unsub", sub))
    catch (Err err)
    {
      if (ext.isRunning) throw err
    }
  }

  ** Deliver the message on the given topic to all matching subscribers
  Void deliver(Ref connRef, Str topic, Message msg)
  {
    obs := makeObservation(DateTime.now, Etc.makeDict(["topic":topic, "payload":msg.payload, "userProps":toUserProps(msg.userProps)]))
    subscriptions.each |MqttSubscription sub|
    {
      if (sub.connRef != connRef) return
      if (!sub.accept(topic)) return
      sub.send(obs)
    }
  }

  ** Convert MQTT user properties to a Dict
  private static Dict toUserProps(StrPair[] props)
  {
    m := Str:Str[:]
    props.each |prop| { m[prop.name] = prop.val }
    return m.isEmpty ? Etc.dict0 : Etc.makeDict(m)
  }
}

**************************************************************************
** MqttSubscription
**************************************************************************

internal const class MqttSubscription : Subscription
{
  new make(MqttObservable observable, Observer observer, Dict config)
    : super(observable, observer, config)
  {
    this.connRef = config["obsMqttConnRef"]
    this.filter  = config["obsMqttTopic"]
    this.qos     = (config["mqttQos"] as Number)?.toInt ?: 0
  }

  ** MQTT connector ref
  const Ref connRef

  ** Configured topic filter
  const Str filter

  ** Configured maximum QoS
  const Int qos

  ** Does this subscription match the given topic
  Bool accept(Str topic) { Topic.matches(topic, filter) }
}

