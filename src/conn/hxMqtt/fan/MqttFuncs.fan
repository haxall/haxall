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
  @Axon { admin = true }
  static Obj? mqttPublish(Obj conn, Str topic, Obj payload, Dict cfg := Etc.emptyDict)
  {
    payload = (payload as Str)?.toBuf ?: throw Err("TODO payload: $payload.typeof")
    msg := HxMsg("mqtt.pub", topic, payload, cfg)
    return MqttLib.cur.conn(Etc.toId(conn)).send(msg).get
  }
}