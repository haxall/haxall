//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  13 Apr 2021   Matthew Giannini  Creation
//

using concurrent

internal class ClientConnAckHandler : ClientHandler
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MqttClient client, ConnAck ack) : super(client)
  {
    this.ack = ack
    this.pendingConnect = client.pendingConnect
  }

  private const ConnAck ack
  private const PendingConn pendingConnect

//////////////////////////////////////////////////////////////////////////
// ConnAckHandler
//////////////////////////////////////////////////////////////////////////

  Obj? run()
  {
    // should never receive a connack after we get connected
    if (state === ClientState.connected)
      throw client.onShutdown(MqttErr("Server sent CONNACK, but already connected"))

    // handle rejected connection
    if (!ack.isSuccess)
    {
      // note - this will complete the pendingConnect future
      client.shutdown(MqttErr(ack.reason))
      if (ack.props.reasonStr != null)
        log.err("CONNECT rejected by server: ${ack.props.reasonStr}")
      return state
    }

    // handle resolution of clean session request vs. server session present response
    requestedClean   := pendingConnect.connect.cleanSession
    requestedRestore := !requestedClean
    try
    {
      if (requestedClean && ack.isSessionPresent)
      {
        // [MQTT5-3.2.2-4]
        throw MqttErr("Requested clean session, but server indicated a session was already present")
      }

      client.transition(ClientState.connecting, ClientState.connected)
    }
    catch (Err err)
    {
      log.err("CONNACK processing failed", err)
      // note - this will complete the pendingConnect future
      client.shutdown(err)
      return state
    }

    debug("CONNACK: $ack.props")

    // set the established client identifier for this connection
    client.clientIdRef.val = ack.props.get(Property.assignedClientId, clientConfig.clientId)

    // open the db
    db.open(clientId)

    // handle resolution of clean session request vs. server session present response
    if (requestedRestore)
    {
      if (!ack.isSessionPresent)
      {
        debug("Resume session for ${clientId} request, but server indicated no session present. Clearing persisted state.")
        db.clear(clientId)
      }
      else
      {
        ClientPublishHandler(client).resume
      }
    }
    else
    {
      // this is a clean session, clear any persisted state
      db.clear(clientId)
    }

    // initialize the quota
    client.quota.val = ack.props.receiveMax

    // complete the connect
    pendingConnect.resp.complete(ack)

    // notify listeners
    client.listeners.fireConnected

    debug("Connected to ${clientConfig.serverUri} as ${clientId}")

    return state
  }
}