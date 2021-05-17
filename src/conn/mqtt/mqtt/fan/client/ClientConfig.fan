//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  05 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**
** Client configuration
**
const class ClientConfig
{
  new make(|This| f)
  {
    f(this)

    if (this.pool == null)
    {
      this.pool = ClientConfig.defaultPool
    }

    if (this.persistence == null)
    {
      this.persistence = ClientMemDb()
    }

    if (maxInFlight < 1 || maxInFlight > max_in_flight_limit)
      throw ArgErr("Invalid maxInFlight: ${maxInFlight}")
  }

  private static const ActorPool defaultPool := ActorPool { it.name = "DefaultMqttClientPool" }

  ** The maximum value the `maxInFlight` configuration parameter can be set to.
  static const Int max_in_flight_limit := 65_535

  ** The MQTT protocol version to use
  const MqttVersion version := MqttVersion.v3_1_1

  ** The client identifier
  const Str clientId := ClientId.gen

  ** The MQTT server uri to connect to.
  **
  ** To connect via the TCP transport use either the 'mqtt' (plain socket)
  ** or 'mqtts' (TLS socket) scheme.
  **
  ** To connect via a websocket use either the 'ws' (plain socket)
  ** or 'wss' (TLS socket) scheme.
  **
  const Uri serverUri := `mqtt://localhost:1883`

  ** TCP socket connection timeout
  const Duration tcpConnectTimeout := 10sec

  ** How long to wait for CONNACK before timing out the connection
  const Duration mqttConnectTimeout := 10sec

  ** Actor pool for client actors
  const ActorPool pool

  ** The persistence layer to use for this client
  const ClientPersistence persistence

  ** Maximum number of messages requiring acknowledgement that can be in-flight.
  const Int maxInFlight := 1000

  // ** Maximum number of QoS 1 and 2 messages that will be queued for sending
  // ** above those that are currently in-flight.
  // const Int maxQueued := 1000

  ** Get the MQTT server URI
  // Uri uri()
  // {
  //   if (websocketPath != null)
  //   {
  //     scheme := useTls ? "wss" : "ws"
  //     path   := websocketPath.relTo(`/`)
  //     return `${scheme}://${serverHost}:${serverPort}/${path}`
  //   }
  //   else
  //   {
  //     scheme := useTls ? "mqtts" : "mqtt"
  //     return `${scheme}://${serverHost}:${serverPort}/`
  //   }
  // }
}