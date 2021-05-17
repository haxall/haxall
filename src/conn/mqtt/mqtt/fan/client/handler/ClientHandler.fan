//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  15 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**
** A client handler is a utility class for processing a MQTT control packet.
**
internal abstract class ClientHandler
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MqttClient client)
  {
    this.client = client
  }

  protected const MqttClient client

//////////////////////////////////////////////////////////////////////////
// ClientHandler
//////////////////////////////////////////////////////////////////////////

  ** Get the client log
  Log log() { client.log }

  ** Convenience to get the client connection state
  ClientState state() { client.state }

  ** Convenience to get the client configuration
  ClientConfig clientConfig() { client.config }

  ** Convenience to get the client MQTT version
  MqttVersion version() { clientConfig.version }

  ** Get the resolved client identifier. If the connack has
  ** been received and the server assigned a client id, use that.
  ** Otherwise use the one from the client config.
  Str clientId(ConnAck? ack := client.pendingConnect.connack(false))
  {
    if (ack == null) return clientConfig.clientId
    return ack.props.get(Property.assignedClientId, clientConfig.clientId)
  }

  ** Get the CONNACK properties for this connection
  Properties connackProps() { client.pendingConnect.connack.props }

  ** Convenience to get the persistence layer
  ClientPersistence db() { clientConfig.persistence}

  protected Void debug(Str msg, Err? err := null)
  {
    client.debug(msg, err)
  }
}
