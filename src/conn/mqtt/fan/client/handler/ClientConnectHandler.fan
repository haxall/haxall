//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  05 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**
** Utility to handle opening a connection to an MQTT server
**
internal class ClientConnectHandler : ClientHandler
{
  new make(MqttClient client, ConnectConfig config) : super(client)
  {
    this.config = config
  }

  private const ConnectConfig config

  Future run()
  {
    // disconnected => connecting (logical MQTT connection); this must be
    // first so we never open a transport on top of a live connection
    client.transition(ClientState.disconnected, ClientState.connecting)

    try
    {
      // establish network connection
      openTransport

      // force config version to match client
      config.versionRef.val = clientConfig.version

      // Update connect packet based on client configuration
      // - set the version
      // - set the client identifier
      // - validate the connect state
      packet := config.packet(clientConfig.clientId).validate

      // create pending request for the connect and send the packet
      client.pendingConnectRef.val = PendingConn(packet)

      // send our CONNECT packet
      client.packetWriter.send(packet)

      // start housekeeping for this connection
      client.sendLater(1sec, ActorMsg("housekeeping", client.connGen.incrementAndGet))

      // start receiving packets from this transport
      client.packetReader.send(client.transportRef.val)
    }
    catch (Err err)
    {
      // the connect never completed so return to the disconnected state
      client.transport?.close
      client.transportRef.val = null
      client.stateRef.val = ClientState.disconnected
      if (!client.pendingConnect.isComplete) client.pendingConnect.resp.completeErr(err)
      throw err
    }

    // we don't transition to the connected state until we receive a CONNACK

    // return the pending response future
    return client.pendingConnect.resp
  }

  private Void openTransport()
  {
    client.transportRef.val = Unsafe(MqttTransport.open(clientConfig))
  }
}