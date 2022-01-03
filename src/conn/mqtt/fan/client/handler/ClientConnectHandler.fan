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
    // establish network connection
    openTransport

    // disconnected => connecting (logical MQTT connection)
    client.transition(ClientState.disconnected, ClientState.connecting)

    // Update connect packet based on client configuration
    // - set the version
    // - set the client identifier
    // - validate the connect state
    packet := config.packet(clientConfig.clientId).validate

    // create pending request for the connect and send the packet
    client.pendingConnectRef.val = PendingConn(packet)

    // send our CONNECT packet
    client.packetWriter.send(packet)

    // start housekeeping
    client.sendLater(1sec, MqttClient.housekeeping)

    // start receiving packets
    client.packetReader.send("loop")

    // we don't transition to the connected state until we receive a CONNACK

    // return the pending response future
    return client.pendingConnect.resp
  }

  private Void openTransport()
  {
    client.transportRef.val = Unsafe(MqttTransport.open(clientConfig))
  }
}