//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   03 Jan 2022  Matthew Giannini  Creation
//

using concurrent
using haystack
using axon
using hx
using hxConn

**
** MQTT connector functions
**
const class MqttFuncs
{
  ** Publish an MQTT message to the given topic on the broker. Currently, the payload
  ** of the message must be a Str.
  **
  ** The following configuration options are supported:
  ** - 'mqttQos': The quality-of-service to use for publishing the message. If not
  ** specified, then QoS '0' is used. See `mqttQos`.
  ** - 'mqttRetain': Should the message be retained on the broker ('true' | 'false').
  ** If not specified, then 'false' is used. See `mqttRetain`.
  ** - 'mqttExpiryInterval': Sets the expiry interval for the message as a Duration.
  ** This is only supported in MQTT 5.
  ** - 'mqttUserProps': A Dict of user properties to include in the message.
  ** This is only supported in MQTT 5.
  **
  ** pre>
  ** read(@mqttConn).mqttPublish("/test", "{a: a JSON object}", {mqttQos: 2, mqttExpiryInterval: 30min, mqttUserProps: {key: "value"}})
  ** <pre
  @Axon { admin = true }
  static Obj? mqttPublish(Obj conn, Str topic, Obj payload, Dict cfg := Etc.emptyDict)
  {
    payload = (payload as Str)?.toBuf ?: throw Err("TODO payload: $payload.typeof")
    msg := HxMsg("mqtt.pub", topic, payload, cfg)
    return MqttLib.cur.conn(Etc.toId(conn)).send(msg).get
  }
}