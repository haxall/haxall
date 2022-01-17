//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   03 Jan 2022  Matthew Giannini  Creation
//

using crypto
using inet
using mqtt
using haystack
using hx
using hxConn
using folio

**
** Dispatch callbacks for the MQTT connector
**
class MqttDispatch : ConnDispatch
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(Obj arg) : super(arg) {}

  private static const HxMsg resubMsg := HxMsg("mqtt.resub")

  private MqttClient? client

  private MqttLib mqttLib() { lib }

//////////////////////////////////////////////////////////////////////////
// Open/Ping/Close
//////////////////////////////////////////////////////////////////////////

  override Void onOpen()
  {
    // configure client
    uriVal := rec["uri"] ?: throw FaultErr("Missing 'uri' tag")
    verVal := MqttVersion.fromStr(rec["mqttVersion"] ?: "v3_1_1")
    config := ClientConfig
    {
      it.serverUri    = uriVal
      it.version      = verVal
      it.clientId     = toClientId
      it.socketConfig = SocketConfig.cur.copy {
        it.keystore = this.mqttKey
        it.connectTimeout = 10sec
        it.receiveTimeout = null
        it.tlsParams = ["appProtocols": this.appProtocols]
      }
    }
    this.client = MqttClient(config, trace.asLog)

    // connect
    resume := ConnectConfig {
      it.cleanSession = false

      // optional username and password
      it.username = rec["username"] as Str
      it.password = db.passwords.get(id.toStr)?.toBuf
    }

    client.connect(resume).get

    // schedule a resubscribe of all topics
    conn.send(resubMsg)
  }

  override Void onClose()
  {
    try
      client.disconnect.get
    finally
      client = null
  }

  override Dict onPing()
  {
    return Etc.emptyDict
  }

//////////////////////////////////////////////////////////////////////////
// Dispatch
//////////////////////////////////////////////////////////////////////////

  override Obj? onReceive(HxMsg msg)
  {
    switch (msg.id)
    {
      case "mqtt.pub":   return onPub(msg.a, msg.b, toConfig(msg.c))
      case "mqtt.sub":   return onSub(toConfig(msg.a))
      case "mqtt.resub": return onResub
      case "mqtt.unsub": return onUnsub(msg.a)
    }
    return super.onReceive(msg)
  }

  private Obj? onPub(Str topic, Buf payload, Dict cfg)
  {
    open.client.publishWith
      .topic(topic)
      .payload(payload)
      .qos((cfg["mqttQos"] as Number).toInt)
      .send
      .get
  }

  private Obj? onSub(Dict cfg)
  {
    // get the topic filter
    filter := cfg["obsMqttTopic"] as Str ?: throw Err("obsMqttTopic no configured")

    // subscribe
    openPin("mqtt.sub")
    ack := client.subscribeWith
      .topicFilter(filter)
      .qos((cfg["mqttQos"] as Number).toInt)
      .onMessage(this.onMessage)
      .send
      .get

    return ack
  }

  private Obj? onResub()
  {
    mqttLib.mqtt.subscriptions.each |MqttSubscription sub|
    {
      // only re-subscribe subscriptions for this connector
      if (sub.connRef == conn.id) onSub(sub.config)
    }
    return null
  }

  ** All subscriptions share this onMessage handler which routes all published
  ** messages to the observable to deliver them to the appropriate task subscriptions
  private |Str, Message| onMessage := |topic, msg| { mqttLib.mqtt.deliver(id, topic, msg) }

  private Obj? onUnsub(MqttSubscription sub)
  {
    try
    {
      return open.client.unsubscribe(sub.filter).get
    }
    finally
    {
      // if there are no more subscriptiosn for this connector
      // then close the subscription pin
      if (!mqttLib.mqtt.connHasSubscriptions(id))
      {
        closePin("mqtt.sub")
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  ** Check the connector rec for the client id. If one is not specified,
  ** generate one and commit it to the rec.
  private Str toClientId()
  {
    id := rec["mqttClientId"] as Str
    if (id == null)
    {
      id = ClientId.gen
      db.commit(Diff(rec, ["mqttClientId": id]))
    }
    return id
  }

  ** Create a set of default values for certain config parameters, and then
  ** merge in the given options to override the defaults.
  private Dict toConfig(Dict opts)
  {
    defs := [
      "mqttQos": rec["mqttQos"] ?: Number.zero,
    ]
    return Etc.dictMerge(Etc.makeDict(defs), opts)
  }

  ** Get a keystore containing the client certificate for this connection
  ** to the broker.
  private KeyStore? mqttKey()
  {
    alias := rec["mqttCertAlias"] as Str
    if (alias == null) return null
    entry := rt.services.crypto.keystore.get(alias) as PrivKeyEntry
    return Crypto.cur.loadKeyStore.set("mqtt", entry)
  }

  ** Get the app protocol(s) to use for this connection to the broker.
  private Str[]? appProtocols()
  {
    protos := rec["mqttAppProtocols"]
    if (protos is Str) return [protos]
    if (protos is Str[]) return protos
    return null

  }
}