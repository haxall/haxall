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
    30.times { if (events[name] == null) Actor.sleep(100ms) }
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
