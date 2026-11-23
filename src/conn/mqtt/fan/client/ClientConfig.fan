//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  05 Apr 2021   Matthew Giannini  Creation
//

using concurrent
using inet

**
** The configuration to use when creating an [MqttClient].
**
const class ClientConfig
{
  new make(|This| f)
  {
    f(this)

    if (this.pool == null)
    {
      this.pool = ActorPool { it.name = "${clientId}-MqttPool" }
    }

    if (this.persistence == null)
    {
      this.persistence = ClientMemDb()
    }

    if (maxInFlight < 1 || maxInFlight > MqttConst.maxPacketId)
      throw ArgErr("Invalid maxInFlight: ${maxInFlight}")
  }

  ** The MQTT protocol version to use
  const MqttVersion version := MqttVersion.v3_1_1

  ** The client identifier
  const Str clientId := ClientId.gen

  ** The MQTT server uri to connect to.
  **
  ** To connect via the TCP transport use either the `mqtt` (plain socket)
  ** or `mqtts` (TLS socket) scheme.
  **
  ** To connect via a websocket use either the `ws` (plain socket)
  ** or `wss` (TLS socket) scheme.
  const Uri serverUri := `mqtt://localhost:1883`

  ** The socket configuration to use.
  const SocketConfig socketConfig := SocketConfig.cur.copy {
    it.connectTimeout = 10sec
    it.receiveTimeout = null
  }

  ** How long to wait for CONNACK before timing out the connection
  const Duration mqttConnectTimeout := 10sec

  ** Maximum number of messages requiring acknowledgement that can be in-flight.
  const Int maxInFlight := 1000

  ** Actor pool for client actors
  const ActorPool pool

  ** The persistence layer to use for this client
  const ClientPersistence persistence

  ** Callback for every message the server publishes to this client,
  ** regardless of which subscriptions it matches. This includes messages
  ** for a resumed session that arrive before the client has subscribed.
  ** It is called on the client actor so it must not block.
  const |Str topic, Message msg|? onMessage

  ** How many times to retry messages that require acknowledgement
  const Int maxRetry := 0

  ** How long to wait between retries for messages that require acknowledgement
  const Duration retryInterval := 10sec

  ** How long until unacknowledged messages timeout
  Duration timeout() { (retryInterval * maxRetry) + retryInterval }
}
