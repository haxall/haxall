//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Nov 2026  Matthew Giannini  Creation
//

using concurrent
using inet
using xeto
using haystack
using obs
using hx
using hxConn
using mqtt

**
** MqttDispatchTest
**
class MqttDispatchTest : HxTest
{
  @HxTestProj
  Void testSharedFilter()
  {
    broker := TestBroker()
    try
    {
      conn := addConn(broker)
      obs  := conn.ext.observables.first
      cfg  := toConfig(conn, "a/b")

      // two subscriptions on the same filter
      a := obs.subscribe(TestObserver(), cfg)
      b := obs.subscribe(TestObserver(), cfg)
      conn.ping.get
      verifyEq(broker.subs, ["a/b", "a/b"])

      // removing one keeps the filter subscribed for the other
      a.unsubscribe
      conn.ping.get
      verifyEq(broker.unsubs, Str[,])

      // removing the last one unsubscribes the filter
      b.unsubscribe
      conn.ping.get
      verifyEq(broker.unsubs, ["a/b"])
    }
    finally broker.close
  }

  @HxTestProj
  Void testReconnect()
  {
    broker := TestBroker()
    try
    {
      conn := addConn(broker)
      obs  := conn.ext.observables.first

      // two subscriptions share a filter at different QoS
      a := TestObserver()
      b := TestObserver()
      c := TestObserver()
      obs.subscribe(a, toConfig(conn, "a/b", 0)); conn.ping.get
      obs.subscribe(b, toConfig(conn, "a/b", 1)); conn.ping.get
      obs.subscribe(c, toConfig(conn, "c/#", 0)); conn.ping.get
      verifyEq(broker.subs, ["a/b", "a/b", "c/#"])
      verifyEq(broker.subQos, [0, 1, 0])
      verifyEq(broker.connects, 1)

      // broker drops the connection, then publishes right after the next CONNACK
      broker.replay.val = "a/b"
      reconnect(conn, broker, 2)
      verifyEq(conn.status, ConnStatus.ok)

      // each filter is resubscribed once at its highest QoS
      verifyEq(broker.subs[3..-1], ["a/b", "c/#"])
      verifyEq(broker.subQos[3..-1], [1, 0])

      // the message published before the resubscribe is delivered
      verifyEq(a.waitFor(1), ["a/b"])
      verifyEq(b.waitFor(1), ["a/b"])
      verifyEq(c.topics, Str[,])
    }
    finally broker.close
  }

  @HxTestProj
  Void testQos2Redelivery()
  {
    broker := TestBroker()
    try
    {
      conn := addConn(broker)
      obs  := conn.ext.observables.first
      a    := TestObserver()
      obs.subscribe(a, toConfig(conn, "a/b", 2)); conn.ping.get

      // broker sends a QoS 2 message on the resumed session and never releases it
      broker.sessionPresent.val = true
      broker.replay.val = "a/b"
      broker.replayQos.val = 2
      reconnect(conn, broker, 2)
      verifyEq(a.waitFor(1), ["a/b"])

      // the same message sent again after another reconnect is not delivered twice
      reconnect(conn, broker, 3)
      Actor.sleep(300ms)
      verifyEq(a.topics, ["a/b"])
    }
    finally broker.close
  }

  @HxTestProj
  Void testStaleDisconnect()
  {
    broker := TestBroker()
    other  := MqttClient(ClientConfig {})
    try
    {
      conn := addConn(broker)
      conn.ping.get
      verifyEq(broker.connects, 1)

      // disconnect of a client we no longer use does not close the connector
      conn.send(HxMsg("mqtt.disconnected", other, null)).get
      conn.ping.get
      verifyEq(conn.status, ConnStatus.ok)
      verifyEq(broker.connects, 1)
    }
    finally
    {
      other.terminate
      broker.close
    }
  }

  @HxTestProj
  Void testSubscribeRejected()
  {
    broker := TestBroker()
    try
    {
      conn := addConn(broker)
      obs  := (MqttObservable)conn.ext.observables.first
      broker.reject.val = "deny/#"
      verifyErr(MqttErr#) { conn.send(HxMsg("mqtt.sub", MqttSubscription(obs, TestObserver(), toConfig(conn, "deny/#")))).get }
      conn.send(HxMsg("mqtt.sub", MqttSubscription(obs, TestObserver(), toConfig(conn, "ok/#")))).get
      verifyEq(broker.subs, ["deny/#", "ok/#"])
    }
    finally broker.close
  }

  @HxTestProj
  Void testSubscribeFailure()
  {
    broker  := TestBroker()
    logged  := AtomicInt()
    handler := |LogRec rec| { if (rec.msg.startsWith("Subscribe failed for 1 of 2 filters") && rec.msg.endsWith("first: deny/# Reason: unspecified_error")) logged.increment }
    Log.addHandler(handler)
    try
    {
      conn := addConn(broker)
      obs  := conn.ext.observables.first

      // a rejected subscribe is logged and shown in the connector details
      broker.reject.val = "deny/#"
      obs.subscribe(TestObserver(), toConfig(conn, "deny/#"))
      obs.subscribe(TestObserver(), toConfig(conn, "ok/#"))
      conn.ping.get
      verifyEq(logged.val, 1)
      verifyDetails(conn, "Filters: 2 [1 subscribed, 1 failed, 0 pending]")
      verifyDetails(conn, "Failed: deny/#: Reason: unspecified_error")

      // it is not logged again while it keeps failing
      reconnect(conn, broker, 2)
      verifyDetails(conn, "Failed: deny/#: Reason: unspecified_error")
      verifyEq(logged.val, 1)

      // housekeeping retries it once the broker accepts it
      broker.reject.val = null
      Actor.sleep(1200ms)
      verifyDetails(conn, "Filters: 2 [2 subscribed, 0 failed, 0 pending]")
      verifyEq(logged.val, 1)
      verifyEq(broker.connects, 2)
    }
    finally
    {
      Log.removeHandler(handler)
      broker.close
    }
  }

  ** Run housekeeping and verify the connector details contain the text
  private Void verifyDetails(Conn conn, Str expected)
  {
    conn.send(HxMsg("forcehk")).get
    details := conn.data?.toStr ?: ""
    verify(details.contains(expected), details)
  }

  @HxTestProj
  Void testMaxPacketSize()
  {
    broker := TestBroker()
    try
    {
      conn := addConn(broker, ["mqttMaxPacketSize":Number(1000)])
      obs  := conn.ext.observables.first
      a    := TestObserver()
      obs.subscribe(a, toConfig(conn, "a/b")); conn.ping.get

      // a message larger than the connector accepts is counted and not delivered
      broker.replay.val = "a/b"
      broker.replaySize.val = 5000
      reconnect(conn, broker, 2)
      verifyDetails(conn, "Delivery Errors: 1 [last: Publish to a/b exceeds max packet size")
      verifyEq(a.topics, Str[,])

      // a message which fits still is
      broker.replaySize.val = 100
      reconnect(conn, broker, 3)
      verifyEq(a.waitFor(1), ["a/b"])
    }
    finally broker.close
  }

  @HxTestProj
  Void testInvalidFilter()
  {
    ext := (MqttExt)addExt("hx.mqtt")
    rec := addRec(["dis":"MQTT", "mqttConn":m, "uri":`mqtt://127.0.0.1:1`])
    proj.sync
    obs := ext.observables.first

    // invalid or missing topic filter fails the subscribe
    verifyErr(MqttErr#) { obs.subscribe(TestObserver(), Etc.makeDict(["obsMqtt":m, "obsMqttConnRef":rec.id, "obsMqttTopic":"a/#/b"])) }
    verifyErr(Err#) { obs.subscribe(TestObserver(), Etc.makeDict(["obsMqtt":m, "obsMqttConnRef":rec.id])) }
    verifyEq(obs.subscriptions.size, 0)
  }

  ** Drop the connection and wait for the connector to open the given
  ** number of connections to the broker
  private Void reconnect(Conn conn, TestBroker broker, Int connects)
  {
    broker.drop
    100.times { if (broker.connects < connects) { Actor.sleep(50ms); conn.ping.get } }
    conn.ping.get
    verifyEq(broker.connects, connects)
  }

  private Conn addConn(TestBroker broker, Str:Obj tags := [:])
  {
    ext := (MqttExt)addExt("hx.mqtt")
    rec := addRec(["dis":"MQTT", "mqttConn":m, "connOpenRetryFreq":Number(1sec), "uri":`mqtt://127.0.0.1:${broker.port}`].addAll(tags))
    proj.sync
    return ext.conn(rec.id)
  }

  private Dict toConfig(Conn conn, Str filter, Int qos := 0)
  {
    Etc.makeDict(["obsMqtt":m, "obsMqttConnRef":conn.id, "obsMqttTopic":filter, "mqttQos":Number(qos)])
  }
}

**************************************************************************
** TestObserver
**************************************************************************

** Records the topic of each observation it receives
internal const class TestObserver : Observer
{
  new make()
  {
    ref := this.topicsRef
    this.actor = Actor(ActorPool()) |Obj? msg->Obj?|
    {
      obs := msg as Observation
      if (obs != null) ref.val = ((Str[])ref.val).dup.add(obs["topic"]).toImmutable
      return null
    }
  }

  const override Actor actor

  const override Dict meta := Etc.dict0

  private const AtomicRef topicsRef := AtomicRef(Str#.emptyList)

  ** Topics observed in order
  Str[] topics() { topicsRef.val }

  ** Wait for the given number of observations and return the topics
  Str[] waitFor(Int size)
  {
    40.times { if (topics.size < size) Actor.sleep(50ms) }
    return topics
  }
}

**************************************************************************
** TestBroker
**************************************************************************

** Accepts one client at a time, acks CONNECT, SUBSCRIBE, UNSUBSCRIBE and
** PINGREQ, and records the topic filters it was asked to subscribe and
** unsubscribe
internal const class TestBroker
{
  new make()
  {
    listener := TcpListener().bind(IpAddr("127.0.0.1"), null)
    this.port = listener.localPort
    this.listenerRef = Unsafe(listener)
    ref := this.listenerRef
    Actor(pool) |->Obj?|
    {
      try { while (true) serve(((TcpListener)ref.val).accept) } catch (Err e) {}
      return null
    }.send(null)
  }

  const Int port

  ** Topic filter to reject with a SUBACK failure
  const AtomicRef reject := AtomicRef(null)

  ** Topic to publish a message to right after each CONNACK
  const AtomicRef replay := AtomicRef(null)

  ** Payload size of the QoS 0 replay message
  const AtomicInt replaySize := AtomicInt(2)

  ** QoS of the replay message: 0 or 2. A QoS 2 message always has the
  ** same packet id and is never released with PUBREL.
  const AtomicInt replayQos := AtomicInt(0)

  ** Set the session present flag in CONNACK
  const AtomicBool sessionPresent := AtomicBool(false)

  private const Unsafe listenerRef

  private const ActorPool pool := ActorPool()

  private const AtomicRef socketRef := AtomicRef(null)

  private const AtomicInt connectsRef := AtomicInt()

  private const AtomicRef subsRef := AtomicRef(Str#.emptyList)

  private const AtomicRef subQosRef := AtomicRef(Int#.emptyList)

  private const AtomicRef unsubsRef := AtomicRef(Str#.emptyList)

  ** Number of CONNECT packets received
  Int connects() { connectsRef.val }

  ** Topic filters subscribed in order
  Str[] subs() { subsRef.val }

  ** Requested QoS of each subscribe in order
  Int[] subQos() { subQosRef.val }

  ** Topic filters unsubscribed in order
  Str[] unsubs() { unsubsRef.val }

  ** Drop the current client connection
  Void drop()
  {
    ((TcpSocket)((Unsafe)socketRef.val).val).close
  }

  Void close()
  {
    ((TcpListener)listenerRef.val).close
    pool.kill
  }

  private Void serve(TcpSocket socket)
  {
    socketRef.val = Unsafe(socket)
    in  := socket.in
    out := socket.out
    try
    {
      while (true)
      {
        type := in.readU1.shiftr(4)
        len  := 0; mult := 1
        while (true)
        {
          x := in.readU1
          len += x.and(0x7f) * mult; mult *= 128
          if (x.and(0x80) == 0) break
        }
        body := in.readBufFully(null, len)
        if (type == 1)
        {
          connectsRef.increment
          out.write(0x20).write(0x02).write(sessionPresent.val ? 0x01 : 0x00).write(0x00)
          topic := replay.val as Str
          if (topic != null && replayQos.val == 2) out.write(0x34).write(topic.size + 6).writeI2(topic.size).writeChars(topic).writeI2(7).writeChars("hi")
          else if (topic != null)
          {
            rem := topic.size + 2 + replaySize.val
            out.write(0x30)
            while (true)
            {
              digit := rem % 128
              rem = rem / 128
              out.write(rem > 0 ? digit.or(0x80) : digit)
              if (rem <= 0) break
            }
            out.writeI2(topic.size).writeChars(topic).writeBuf(Buf().fill('x', replaySize.val).flip)
          }
          out.flush
        }
        else if (type == 8)
        {
          pid    := body.readU2
          filter := body.readChars(body.readU2)
          add(subsRef, filter)
          add(subQosRef, body.read)
          out.write(0x90).write(0x03).writeI2(pid).write(filter == reject.val ? 0x80 : 0x00).flush
        }
        else if (type == 10)
        {
          pid := body.readU2
          add(unsubsRef, body.readChars(body.readU2))
          out.write(0xb0).write(0x02).writeI2(pid).flush
        }
        else if (type == 12) out.write(0xd0).write(0x00).flush
      }
    }
    catch (Err e) {}
    finally socket.close
  }

  private static Void add(AtomicRef ref, Obj val)
  {
    ref.val = ((List)ref.val).dup.add(val).toImmutable
  }
}
