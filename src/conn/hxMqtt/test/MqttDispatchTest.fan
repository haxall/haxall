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
      ext  := (MqttExt)addExt("hx.mqtt")
      rec  := addRec(["dis":"MQTT", "mqttConn":m, "uri":`mqtt://127.0.0.1:${broker.port}`])
      proj.sync
      conn := ext.conn(rec.id)
      obs  := ext.observables.first
      cfg  := Etc.makeDict(["obsMqtt":m, "obsMqttConnRef":rec.id, "obsMqttTopic":"a/b"])

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
}

**************************************************************************
** TestObserver
**************************************************************************

internal const class TestObserver : Observer
{
  const override Actor actor := Actor(ActorPool()) |->Obj?| { null }

  const override Dict meta := Etc.dict0
}

**************************************************************************
** TestBroker
**************************************************************************

** Accepts one client, acks CONNECT, SUBSCRIBE, UNSUBSCRIBE and PINGREQ,
** and records the topic filters it was asked to subscribe and unsubscribe
internal const class TestBroker
{
  new make()
  {
    listener := TcpListener().bind(IpAddr("127.0.0.1"), null)
    this.port = listener.localPort
    this.listenerRef = Unsafe(listener)
    ref := this.listenerRef
    Actor(pool) |->Obj?| { serve(((TcpListener)ref.val).accept); return null }.send(null)
  }

  const Int port

  private const Unsafe listenerRef

  private const ActorPool pool := ActorPool()

  private const AtomicRef subsRef := AtomicRef(Str#.emptyList)

  private const AtomicRef unsubsRef := AtomicRef(Str#.emptyList)

  ** Topic filters subscribed in order
  Str[] subs() { subsRef.val }

  ** Topic filters unsubscribed in order
  Str[] unsubs() { unsubsRef.val }

  Void close()
  {
    ((TcpListener)listenerRef.val).close
    pool.kill
  }

  private Void serve(TcpSocket socket)
  {
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
        switch (type)
        {
          case 1:  out.write(0x20).write(0x02).write(0x00).write(0x00).flush
          case 8:  add(subsRef, filter(body)); out.write(0x90).write(0x03).writeI2(body.readU2).write(0x00).flush
          case 10: add(unsubsRef, filter(body)); out.write(0xb0).write(0x02).writeI2(body.readU2).flush
          case 12: out.write(0xd0).write(0x00).flush
        }
      }
    }
    catch (Err e) {}
    finally socket.close
  }

  ** Read the first topic filter after the packet id (v3.1.1)
  private static Str filter(Buf body)
  {
    filter := body.seek(2).readChars(body.readU2)
    body.seek(0)
    return filter
  }

  private static Void add(AtomicRef ref, Str filter)
  {
    ref.val = ((Str[])ref.val).dup.add(filter).toImmutable
  }
}
