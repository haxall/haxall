//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  23 Nov 2026   Matthew Giannini  Creation
//

using concurrent
using inet

class ClientTest : Test
{
  Void testKeepAlive()
  {
    // server answers pings, so the client stays connected
    verifyKeepAlive(true)

    // server goes silent after CONNACK, so the client must disconnect
    verifyKeepAlive(false)
  }

  private Void verifyKeepAlive(Bool pingResp)
  {
    server := SilentServer { it.pingResp = pingResp }
    events := ConcurrentMap()
    client := makeClient(server, events)
    try
    {
      client.connect(ConnectConfig { it.keepAlive = 1sec }).get(5sec)
      verifyEq(client.state, ClientState.connected)

      Actor.sleep(4sec)
      if (pingResp)
      {
        verifyEq(client.state, ClientState.connected)
        verifyNull(events["disconnected"])
      }
      else
      {
        verifyEq(client.state, ClientState.disconnected)
        verify(events["disconnected"].toStr.startsWith("sys::TimeoutErr"))
      }
    }
    finally
    {
      client.terminate
      server.close
    }
  }

  Void testConnectRefused()
  {
    // 3.1.1 return codes map to reason codes with and without clean session
    [true, false].each |clean|
    {
      verifyConnectRefused(1, clean, ReasonCode.unsupported_protocol_version)
      verifyConnectRefused(2, clean, ReasonCode.client_identifier_not_valid)
      verifyConnectRefused(3, clean, ReasonCode.server_unavailable)
      verifyConnectRefused(4, clean, ReasonCode.bad_username_or_password)
      verifyConnectRefused(5, clean, ReasonCode.not_authorized)
    }
  }

  private Void verifyConnectRefused(Int code, Bool clean, ReasonCode expected)
  {
    server := SilentServer { it.connAck = code; it.closeOnConnAck = true }
    events := ConcurrentMap()
    client := makeClient(server, events)
    try
    {
      MqttErr? err
      try
        client.connect(ConnectConfig { it.cleanSession = clean }).get(5sec)
      catch (MqttErr e)
        err = e
      verifyEq(err?.reason, expected)
      verifyEq(client.state, ClientState.disconnected)
      verifyEq(waitFor(events, "disconnected"), err.toStr)
      verify(client.debugClient.contains("State: disconnected"))
    }
    finally
    {
      client.terminate
      server.close
    }
  }

  Void testConnAckTimeout()
  {
    [true, false].each |clean|
    {
      server := SilentServer { it.connAck = null }
      events := ConcurrentMap()
      client := makeClient(server, events)
      try
      {
        verifyErrMsg(TimeoutErr#, "CONNACK not received within ${1sec.toLocale}")
        {
          client.connect(ConnectConfig { it.cleanSession = clean }).get(5sec)
        }
        verifyEq(client.state, ClientState.disconnected)
        verify(waitFor(events, "disconnected").startsWith("sys::TimeoutErr"))
      }
      finally
      {
        client.terminate
        server.close
      }
    }
  }

  Void testServerClose()
  {
    // server closes the socket after a successful CONNACK
    server := SilentServer { it.closeOnConnAck = true }
    events := ConcurrentMap()
    client := makeClient(server, events)
    try
    {
      verify(client.debugClient.contains("State: disconnected"))
      client.connect.get(5sec)
      verifyEq(waitFor(events, "disconnected"), "sys::IOErr: Connection closed by broker")
      verifyEq(client.state, ClientState.disconnected)
    }
    finally
    {
      client.terminate
      server.close
    }
  }

  Void testConnectWhenConnected()
  {
    server := SilentServer()
    events := ConcurrentMap()
    client := makeClient(server, events)
    try
    {
      client.connect(ConnectConfig { it.keepAlive = 1sec }).get(5sec)

      // a second connect fails and must not disturb the live connection
      verifyErr(MqttErr#) { client.connect }
      Actor.sleep(4sec)
      verifyEq(client.state, ClientState.connected)
      verifyNull(events["disconnected"])
    }
    finally
    {
      client.terminate
      server.close
    }
  }

  Void testConnectFailed()
  {
    server := SilentServer()
    events := ConcurrentMap()
    client := makeClient(server, events)
    try
    {
      // invalid connect is rejected after the transport is open
      verifyErr(MqttErr#) { client.connect(ConnectConfig { it.password = "pw".toBuf }) }
      verifyEq(client.state, ClientState.disconnected)

      // connect packet fails to encode after the pending connect is created
      verifyErr(ArgErr#) { client.connect(ConnectConfig { it.keepAlive = 1day }) }
      verifyEq(client.state, ClientState.disconnected)

      // requests fail instead of waiting on a connect that never happened
      verifyErr(MqttErr#) { client.publishWith.topic("a").qos0.send }

      // nothing got on the wire so there is no disconnect event
      Actor.sleep(200ms)
      verifyNull(events["disconnected"])

      // the client can still connect
      client.connect.get(5sec)
      verifyEq(client.state, ClientState.connected)
    }
    finally
    {
      client.terminate
      server.close
    }
  }

  Void testSubscribeRetry()
  {
    // 3.1.1 resends an unanswered SUBSCRIBE, 5.0 must not [MQTT5-4.4.0-1]
    verifySubscribeRetry(MqttVersion.v3_1_1, 2)
    verifySubscribeRetry(MqttVersion.v5, 1)
  }

  private Void verifySubscribeRetry(MqttVersion version, Int expected)
  {
    server := ScriptServer(version)
    client := MqttClient(ClientConfig {
      it.serverUri     = server.uri
      it.version       = version
      it.clientId      = "clientTest"
      it.maxRetry      = 1
      it.retryInterval = 1sec
    })
    try
    {
      server.ackSub.val = false
      client.connect.get(5sec)

      // offset from housekeeping so the retry and timeout land on different ticks
      Actor.sleep(300ms)
      f := client.subscribeWith.topicFilter("a/b").qos0.send
      verifyErr(TimeoutErr#) { f.get(6sec) }
      verifyEq(server.count("subscribe"), expected)
    }
    finally
    {
      client.terminate
      server.close
    }
  }

  Void testResume()
  {
    server := ScriptServer()
    client := MqttClient(ClientConfig { it.serverUri = server.uri; it.clientId = "clientTest" })
    resume := ConnectConfig { it.cleanSession = false }
    try
    {
      client.connect(resume).get(5sec)

      // leave a QoS 2 publish waiting on PUBCOMP and QoS 1 publishes on PUBACK
      server.ackRel.val = false
      client.publishWith.topic("t").payload("q2".toBuf).qos2.send
      20.times { if (server.count("pubrel") < 1) Actor.sleep(50ms) }
      server.ackPub.val = false
      20.times |i| { client.publishWith.topic("t").payload("m${i}".toBuf).qos1.send }
      20.times { if (server.count("publish") < 21) Actor.sleep(50ms) }
      verifyEq(server.count("pubrel"), 1)
      verifyEq(server.count("publish"), 21)

      // drop the connection and resume the session
      mark := server.received.size
      server.drop
      40.times { if (client.state !== ClientState.disconnected) Actor.sleep(50ms) }
      verifyEq(client.state, ClientState.disconnected)
      server.sessionPresent.val = true
      server.ackPub.val = true
      server.ackRel.val = true
      client.connect(resume).get(5sec)
      40.times { if (server.received.size < mark + 22) Actor.sleep(50ms) }

      // PUBREL and every PUBLISH is resent in the order it was first sent
      expected := ["connect", "pubrel"]
      20.times |i| { expected.add("publish m${i} dup") }
      verifyEq(server.received[mark..-1], expected)
    }
    finally
    {
      client.terminate
      server.close
    }
  }

  Void testPubRecErr()
  {
    // server grants a receive maximum of one and rejects every publish
    server := ScriptServer(MqttVersion.v5)
    client := MqttClient(ClientConfig {
      it.serverUri = server.uri
      it.version   = MqttVersion.v5
      it.clientId  = "clientTest"
    })
    try
    {
      server.pubRecReason.val = 0x80
      client.connect.get(5sec)

      // the rejected publish gives its quota back for the next one
      2.times
      {
        MqttErr? err
        try
          client.publishWith.topic("t").qos2.send.get(5sec)
        catch (MqttErr e)
          err = e
        verifyEq(err?.msg?.startsWith("Publish failed"), true)
      }
      verifyEq(server.count("publish"), 2)
      verifyEq(server.count("pubrel"), 0)
    }
    finally
    {
      client.terminate
      server.close
    }
  }

  Void testWriteStall()
  {
    server := ScriptServer()
    events := ConcurrentMap()
    client := MqttClient(ClientConfig { it.serverUri = server.uri; it.clientId = "clientTest" })
    try
    {
      client.addListener(TestClientListener(events))
      client.connect(ConnectConfig { it.keepAlive = 1sec }).get(5sec)

      // server stops reading so QoS 0 publishes back up behind the socket
      server.stall.val = true
      16.times { client.publishWith.topic("t").payload(Buf().fill(0, 1024*1024)).qos0.send }

      // the client actor is not blocked, so keep alive closes the connection
      verifyEq(waitFor(events, "disconnected")?.startsWith("sys::TimeoutErr"), true)
      verifyEq(client.state, ClientState.disconnected)
    }
    finally
    {
      client.terminate
      server.close
    }
  }

  private MqttClient makeClient(SilentServer server, ConcurrentMap events)
  {
    MqttClient(ClientConfig {
      it.serverUri          = `mqtt://127.0.0.1:${server.port}`
      it.clientId           = "clientTest"
      it.mqttConnectTimeout = 1sec
    }).addListener(TestClientListener(events))
  }

  ** Wait for the listener event and return it, or null if it never fires
  private Str? waitFor(ConcurrentMap events, Str name)
  {
    80.times { if (events[name] == null) Actor.sleep(100ms) }
    return events[name]
  }
}

**************************************************************************
** TestClientListener
**************************************************************************

internal const class TestClientListener : ClientListener
{
  new make(ConcurrentMap events) { this.events = events }

  const ConcurrentMap events

  override Void onDisconnected(Err? err) { events["disconnected"] = err?.toStr ?: "null" }
}

**************************************************************************
** SilentServer
**************************************************************************

** Accepts one client at a time, answers CONNECT as configured, and
** then only answers PINGREQ if pingResp is true
internal const class SilentServer
{
  new make(|This|? f := null)
  {
    f?.call(this)
    listener := TcpListener().bind(IpAddr("127.0.0.1"), null)
    this.port = listener.localPort
    this.listenerRef = Unsafe(listener)
    ref  := this.listenerRef
    code := this.connAck
    drop := this.closeOnConnAck
    ping := this.pingResp
    Actor(pool) |->Obj?|
    {
      try { while (true) serve(((TcpListener)ref.val).accept, code, drop, ping) } catch (Err e) {}
      return null
    }.send(null)
  }

  ** CONNACK return code to answer CONNECT with, or null to never answer
  const Int? connAck := 0

  ** Close the socket after sending the CONNACK
  const Bool closeOnConnAck := false

  ** Answer PINGREQ with PINGRESP
  const Bool pingResp := true

  const Int port

  private const Unsafe listenerRef

  private const ActorPool pool := ActorPool()

  Void close()
  {
    ((TcpListener)listenerRef.val).close
    pool.kill
  }

  private static Void serve(TcpSocket socket, Int? connAck, Bool closeOnConnAck, Bool pingResp)
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
          b := in.readU1
          len += b.and(0x7f) * mult; mult *= 128
          if (b.and(0x80) == 0) break
        }
        in.skip(len)
        if (type == 1 && connAck != null)
        {
          out.write(0x20).write(0x02).write(0x00).write(connAck).flush
          if (closeOnConnAck) break
        }
        else if (type == 12 && pingResp) out.write(0xd0).write(0x00).flush
      }
    }
    catch (Err e) {}
    finally socket.close
  }
}

**************************************************************************
** ScriptServer
**************************************************************************

** Accepts one client at a time and records the packets it receives.
** Its fields control how it answers and may be changed at any time.
internal const class ScriptServer
{
  new make(MqttVersion version := MqttVersion.v3_1_1)
  {
    listener := TcpListener().bind(IpAddr("127.0.0.1"), null)
    this.version = version
    this.port = listener.localPort
    this.listenerRef = Unsafe(listener)
    ref := this.listenerRef
    Actor(pool) |->Obj?|
    {
      try { while (true) serve(((TcpListener)ref.val).accept) } catch (Err e) {}
      return null
    }.send(null)
  }

  const MqttVersion version

  const Int port

  ** Set the session present flag in CONNACK
  const AtomicBool sessionPresent := AtomicBool(false)

  ** Answer SUBSCRIBE with SUBACK
  const AtomicBool ackSub := AtomicBool(true)

  ** Answer PUBLISH with PUBACK or PUBREC
  const AtomicBool ackPub := AtomicBool(true)

  ** Answer PUBREL with PUBCOMP
  const AtomicBool ackRel := AtomicBool(true)

  ** Reason code to send in PUBREC (5.0 only)
  const AtomicInt pubRecReason := AtomicInt(0)

  ** Stop reading from the client
  const AtomicBool stall := AtomicBool(false)

  private const Unsafe listenerRef

  private const ActorPool pool := ActorPool()

  private const AtomicRef socketRef := AtomicRef(null)

  private const AtomicRef receivedRef := AtomicRef(Str#.emptyList)

  Uri uri() { `mqtt://127.0.0.1:${port}` }

  ** Packets received in order, except PINGREQ. A PUBLISH is recorded
  ** with its payload and whether the DUP flag was set.
  Str[] received() { receivedRef.val }

  ** Number of packets received which start with the given prefix
  Int count(Str prefix) { received.findAll { it.startsWith(prefix) }.size }

  ** Drop the current client connection
  Void drop() { ((TcpSocket)((Unsafe)socketRef.val).val).close }

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
    v5  := version.is5
    try
    {
      while (true)
      {
        if (stall.val) { Actor.sleep(100ms); continue }
        byte1 := in.readU1
        type  := byte1.shiftr(4)
        flags := byte1.and(0x0f)
        len   := 0; mult := 1
        while (true)
        {
          b := in.readU1
          len += b.and(0x7f) * mult; mult *= 128
          if (b.and(0x80) == 0) break
        }
        body := in.readBufFully(null, len)
        if (type == 1)
        {
          // 5.0 CONNACK grants a receive maximum of one
          record("connect")
          sp := sessionPresent.val ? 1 : 0
          if (v5) out.write(0x20).write(0x06).write(sp).write(0x00).write(0x03).write(0x21).writeI2(1).flush
          else out.write(0x20).write(0x02).write(sp).write(0x00).flush
        }
        else if (type == 3)
        {
          qos := flags.shiftr(1).and(0x03)
          body.readChars(body.readU2)
          pid := qos > 0 ? body.readU2 : 0
          if (v5) body.seek(body.pos + 1 + body.read)
          record("publish ${body.readAllStr}" + (flags.and(0x08) != 0 ? " dup" : ""))
          if (!ackPub.val) continue
          if (qos == 1) out.write(0x40).write(0x02).writeI2(pid).flush
          else if (qos == 2 && v5) out.write(0x50).write(0x03).writeI2(pid).write(pubRecReason.val).flush
          else if (qos == 2) out.write(0x50).write(0x02).writeI2(pid).flush
        }
        else if (type == 6)
        {
          record("pubrel")
          if (ackRel.val) out.write(0x70).write(0x02).writeI2(body.readU2).flush
        }
        else if (type == 8)
        {
          record("subscribe")
          if (!ackSub.val) continue
          if (v5) out.write(0x90).write(0x04).writeI2(body.readU2).write(0x00).write(0x00).flush
          else out.write(0x90).write(0x03).writeI2(body.readU2).write(0x00).flush
        }
        else if (type == 12) out.write(0xd0).write(0x00).flush
      }
    }
    catch (Err e) {}
    finally socket.close
  }

  private Void record(Str packet)
  {
    receivedRef.val = received.dup.add(packet).toImmutable
  }
}
