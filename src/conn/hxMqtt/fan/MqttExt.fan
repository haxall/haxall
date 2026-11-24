//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   03 Jan 2022  Matthew Giannini  Creation
//

using concurrent
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

  ** Subscriptions of the connector grouped by their topic filter
  MqttFilter[] filters(Ref connRef)
  {
    acc := Str:MqttFilter[:] { ordered = true }
    subscriptions.each |MqttSubscription sub|
    {
      if (sub.connRef == connRef) acc.getOrAdd(sub.filter) |Str filter->MqttFilter| { MqttFilter(filter) }.subs.add(sub)
    }
    return acc.vals
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

  ** Outcome of the connector's last SUBSCRIBE for the topic
  ** filter, or null if it has not tried to subscribe it
  MqttSubState? state() { stateRef.val }
  const AtomicRef stateRef := AtomicRef(null)

  ** Does this subscription match the given topic
  Bool accept(Str topic) { Topic.matches(topic, filter) }
}

**************************************************************************
** MqttSubState
**************************************************************************

**
** Outcome of a SUBSCRIBE for a subscription's topic filter
**
internal const class MqttSubState
{
  new make(Int? qos, Str? err, Int ticks := Duration.nowTicks)
  {
    this.qos   = qos
    this.err   = err
    this.ticks = ticks
  }

  ** QoS the topic filter is subscribed with on the connector's
  ** open connection, or null if it is not subscribed
  const Int? qos

  ** Why the broker did not make the subscription, or null if it did
  const Str? err

  ** Ticks when the SUBSCRIBE was tried
  const Int ticks
}

**************************************************************************
** MqttFilter
**************************************************************************

**
** The subscriptions of one connector which share a topic filter. The
** broker and client track one subscription per topic filter. This is a
** view built from the observable's subscriptions when it is needed.
**
internal class MqttFilter
{
  new make(Str filter) { this.filter = filter }

  const Str filter

  MqttSubscription[] subs := [,]

  ** Did the last `update` record a failure which is not the
  ** same as the failure the topic filter already had
  Bool isNewFailure { private set }

  ** Highest QoS requested by the subscriptions
  Int qos() { subs.max |a, b| { a.qos <=> b.qos }?.qos ?: 0 }

  ** Outcome of the most recent SUBSCRIBE, or null if none was tried
  MqttSubState? state()
  {
    MqttSubState? last
    subs.each |sub|
    {
      state := sub.state
      if (state != null && (last == null || state.ticks > last.ticks)) last = state
    }
    return last
  }

  ** Is the topic filter subscribed at the QoS the subscriptions need
  Bool isSubscribed() { (state?.qos ?: -1) >= qos }

  ** Record the outcome of a SUBSCRIBE on the subscriptions
  Void update(Int? qos, Str? err)
  {
    isNewFailure = err != null && err != state?.err
    set(MqttSubState(qos, err))
  }

  ** The connection closed so the topic filter is no longer subscribed.
  ** The failure is kept so that it is not reported again as a new one.
  Void onClose()
  {
    old := state
    if (old?.qos != null) set(MqttSubState(null, old.err, old.ticks))
  }

  private Void set(MqttSubState state)
  {
    subs.each |sub| { sub.stateRef.val = state }
  }
}
