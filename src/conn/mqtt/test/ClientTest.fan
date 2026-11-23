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
    server := SilentServer(pingResp)
    events := ConcurrentMap()
    client := MqttClient(ClientConfig {
      it.serverUri = `mqtt://127.0.0.1:${server.port}`
      it.clientId  = "keepAliveTest"
    })
    try
    {
      client.addListener(TestClientListener(events))
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

** Accepts one client, sends CONNACK, and then only answers PINGREQ
** if pingResp is true
internal const class SilentServer
{
  new make(Bool pingResp)
  {
    listener := TcpListener().bind(IpAddr("127.0.0.1"), null)
    this.port = listener.localPort
    this.listenerRef = Unsafe(listener)
    ref := this.listenerRef
    Actor(pool) |->Obj?| { serve(((TcpListener)ref.val).accept, pingResp); return null }.send(null)
  }

  const Int port

  private const Unsafe listenerRef

  private const ActorPool pool := ActorPool()

  Void close()
  {
    ((TcpListener)listenerRef.val).close
    pool.kill
  }

  private static Void serve(TcpSocket socket, Bool pingResp)
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
        if (type == 1) out.write(0x20).write(0x02).write(0x00).write(0x00).flush
        else if (type == 12 && pingResp) out.write(0xd0).write(0x00).flush
      }
    }
    catch (Err e) {}
    finally socket.close
  }
}
