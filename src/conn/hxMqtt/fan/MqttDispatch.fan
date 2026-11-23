//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   03 Jan 2022  Matthew Giannini  Creation
//

using concurrent
using crypto
using inet
using mqtt
using xeto
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

  protected MqttClient? client

  ** Topic filters subscribed on the current client mapped to their QoS
  private Str:Int subscribed := [:]

  protected MqttExt mqttLib() { ext }

//////////////////////////////////////////////////////////////////////////
// Open/Ping/Close
//////////////////////////////////////////////////////////////////////////

  override Void onOpen()
  {
    // configure client
    uriVal   := rec["uri"] ?: throw FaultErr("Missing 'uri' tag")
    verVal   := MqttVersion.fromStr(rec["mqttVersion"] ?: "v3_1_1")
    clientId := toClientId

    // route every message to the observable, which delivers it to the
    // matching subscriptions; this includes messages the broker queued
    // for our session that arrive before we resubscribe
    obs       := mqttLib.mqtt
    connId    := id
    onMessage := |Str topic, Message msg| { obs.deliver(connId, topic, msg) }

    config := ClientConfig
    {
      it.serverUri     = uriVal
      it.version       = verVal
      it.clientId      = clientId
      it.maxRetry      = (rec.get("mqttMaxRetry") ?: Number.zero)->toInt
      it.retryInterval = (rec.get("mqttRetryInterval") ?: Number(10sec))->toDuration
      it.onMessage     = onMessage
      it.socketConfig  = SocketConfig.cur.copy {
        it.keystore       = this.mqttKey
        it.connectTimeout = 10sec
        it.receiveTimeout = null
        it.tlsParams      = ["appProtocols": this.appProtocols]
      }
    }
    this.subscribed.clear
    this.client = MqttClient(config, trace.asLog)
    client.addListener(MqttConnListener(conn, client))

    try
    {
      // connect
      resume := ConnectConfig {
        it.cleanSession = rec["mqttCleanSession"] == true
        it.sessionExpiryInterval = toSessionExpiryInterval

        // optional username and password
        it.username = rec["username"] as Str
        it.password = db.passwords.get(id.toStr)?.toBuf
      }

      // wait longer than the client so that its error is the one reported
      client.connect(resume).get(config.mqttConnectTimeout + 5sec)
    }
    catch (Err err)
    {
      this.terminate
      throw err
    }

    // schedule a resubscribe of all topics
    conn.send(resubMsg)
  }

  override Void onClose()
  {
    try
    {
      client?.disconnect?.get(15sec)
    }
    catch (Err ignore) { }
    finally
    {
      this.terminate
    }
  }

  private Void terminate()
  {
    client?.terminate
    client = null
    subscribed.clear
  }

  override Dict onPing()
  {
    return Etc.dict0
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
      case "mqtt.disconnected": return onDisconnected(msg.a, msg.b)
    }
    return super.onReceive(msg)
  }

  private Obj? onPub(Str topic, Buf payload, Dict cfg)
  {
    open
    client.publishWith
      .topic(topic)
      .payload(payload)
      .qos(((Number)cfg["mqttQos"]).toInt)
      .retain((cfg["mqttRetain"] as Bool) == true)
      .expiryInterval((cfg["mqttExpiryInterval"] as Number)?.toDuration)
      .userProps(userPropsFromDict(cfg["mqttUserProps"] as Dict))
      .send
      .get
    return null
  }

  ** The client lost its connection to the broker
  private Obj? onDisconnected(MqttClient client, Err? err)
  {
    // ignore a client we already closed
    if (client === this.client) close(err)
    return null
  }

  private Obj? onSub(Dict cfg)
  {
    // get the topic filter
    filter := cfg["obsMqttTopic"] as Str ?: throw Err("obsMqttTopic not configured")
    qos := cfg["mqttQos"] as Number ?: throw Err("mqttQos not configured")

    // a new subscription always sends SUBSCRIBE so that it receives
    // retained messages; if the open failed we resubscribe on reopen
    openPin("mqtt.sub")
    if (client == null) return null
    subscribe(filter, qos.toInt.max(filters[filter] ?: 0))
    return null
  }

  private Obj? onResub()
  {
    filters.each |qos, filter|
    {
      // skip filters subscribed since this client was opened
      if ((subscribed[filter] ?: -1) >= qos) return
      try { subscribe(filter, qos) } catch (Err err) { /* already traced */ }
    }
    return null
  }

  ** Topic filters of this connector's subscriptions mapped to the
  ** highest QoS any of them requests. The broker and client track one
  ** subscription per filter.
  private Str:Int filters()
  {
    acc := Str:Int[:] { ordered = true }
    mqttLib.mqtt.subscriptions.each |MqttSubscription sub|
    {
      if (sub.connRef == id) acc[sub.filter] = sub.qos.max(acc[sub.filter] ?: 0)
    }
    return acc
  }

  private Void subscribe(Str filter, Int qos)
  {
    try
    {
      client.subscribeWith.topicFilter(filter).qos(qos).send.get
      subscribed[filter] = qos
    }
    catch (Err err)
    {
      trace.asLog.err("Failed to subscribe to ${filter}", err)
      throw err
    }
  }

  private Obj? onUnsub(MqttSubscription sub)
  {
    // the broker and client track one subscription per filter, so keep
    // it while another subscription on this connector still uses it
    if (mqttLib.mqtt.subscriptions.any |MqttSubscription s->Bool| { s.connRef == id && s.filter == sub.filter }) return null

    try
    {
      open.client.unsubscribe(sub.filter).get
      subscribed.remove(sub.filter)
      return null
    }
    catch (Err err)
    {
      trace.asLog.err("Failed to unsubscribe filter: $sub.filter", err)
      throw err
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
// Housekeeping
//////////////////////////////////////////////////////////////////////////

  override Void onHouseKeeping()
  {
    setConnData(client?.debugClient)
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
      "mqttQos": Number.zero,
    ]
    return Etc.dictMerge(Etc.makeDict(defs), opts)
  }

  ** Get a keystore containing the client certificate for this connection
  ** to the broker.
  private KeyStore? mqttKey()
  {
    alias := rec["mqttCertAlias"] as Str
    if (alias == null) return null
    entry := ext.sys.crypto.keystore.get(alias) as PrivKeyEntry ?: throw FaultErr("mqttCertAlias is not a private key: ${alias}")
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

  private Duration toSessionExpiryInterval()
  {
    v := (rec["mqttSessionExpiryInterval"] as Number)?.toDuration
    if (v == null) v = MqttConst.sessionExpiresOnClose
    else if (v == -1sec) v = MqttConst.sessionNeverExpires
    return v
  }

  private static Str:Str userPropsFromDict(Dict? dict)
  {
    props := Str:Str[:]
    dict?.each |value, name| {props[name] = value.toStr}
    return props
  }
}

**************************************************************************
** MqttConnListener
**************************************************************************

**
** Routes client disconnects to the connector actor
**
internal const class MqttConnListener : ClientListener
{
  new make(Conn conn, MqttClient client)
  {
    this.conn   = conn
    this.client = client
  }

  const Conn conn

  const MqttClient client

  override Void onDisconnected(Err? err)
  {
    conn.send(HxMsg("mqtt.disconnected", client, err))
  }
}
