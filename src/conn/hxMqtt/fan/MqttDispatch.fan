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

  ** Max packet size accepted from the broker unless configured
  private static const Int defMaxPacketSize := 16 * 1024 * 1024

  protected MqttClient? client

  ** Session state shared by every client this connector opens, so that
  ** unacknowledged messages survive a reconnect when the session resumes
  private ClientPersistence sessionDb := ClientMemDb()

  protected MqttExt mqttExt() { ext }

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
    obs       := mqttExt.mqtt
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
      it.persistence   = this.sessionDb
      it.socketConfig  = SocketConfig.cur.copy {
        it.keystore       = this.mqttKey
        it.connectTimeout = 10sec
        it.receiveTimeout = null
        it.tlsParams      = ["appProtocols": this.appProtocols]
      }
    }
    this.client = MqttClient(config, trace.asLog)
    client.addListener(MqttConnListener(conn, client))

    try
    {
      // connect
      resume := ConnectConfig {
        it.cleanSession = rec["mqttCleanSession"] == true
        it.sessionExpiryInterval = toSessionExpiryInterval
        it.maxPacketSize = (rec["mqttMaxPacketSize"] as Number)?.toInt ?: defMaxPacketSize

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
    filters.each |f| { f.onClose }
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
      case "mqtt.pub":   return onPub(msg.a, msg.b, msg.c)
      case "mqtt.sub":   return onSub(msg.a)
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
      .qos((cfg["mqttQos"] as Number)?.toInt ?: 0)
      .retain((cfg["mqttRetain"] as Bool) == true)
      .expiryInterval((cfg["mqttExpiryInterval"] as Number)?.toDuration)
      .userProps(userPropsFromDict(cfg["mqttUserProps"] as Dict))
      .send
      .get(conn.timeout)
    return null
  }

  ** The client lost its connection to the broker
  private Obj? onDisconnected(MqttClient client, Err? err)
  {
    // ignore a client we already closed
    if (client === this.client) close(err)
    return null
  }

  private Obj? onSub(MqttSubscription sub)
  {
    // a new subscription always sends SUBSCRIBE so that it receives
    // retained messages; if the open failed we resubscribe on reopen
    openPin("mqtt.sub")
    if (client == null) return null

    // the subscription may not be registered with the observable yet
    all := filters
    f   := all.find |x| { x.filter == sub.filter } ?: all.add(MqttFilter(sub.filter)).last
    if (!f.subs.containsSame(sub)) f.subs.add(sub)

    err := subscribe(f)
    logFailures(all)
    if (err != null) throw err
    return null
  }

  private Obj? onResub(MqttFilter[] all := filters)
  {
    all.eachWhile |f|
    {
      if (f.isSubscribed) return null

      // stop if the broker is not answering or the connection was lost,
      // because the rest of the topic filters would only wait as well
      err := subscribe(f)
      return err is TimeoutErr || client.state !== ClientState.connected ? "stop" : null
    }
    logFailures(all)
    return null
  }

  ** This connector's subscriptions grouped by topic filter
  private MqttFilter[] filters() { mqttExt.mqtt.filters(id) }

  ** Subscribe a topic filter and record the outcome on its
  ** subscriptions. Return the error if it failed.
  private Err? subscribe(MqttFilter f)
  {
    qos := f.qos
    try
    {
      client.subscribeWith.topicFilter(f.filter).qos(qos).send.get
      f.update(qos, null)
      return null
    }
    catch (Err err)
    {
      trace.asLog.err("Failed to subscribe to ${f.filter}", err)

      // a lost connection is not a failure of the subscription; keep the
      // reason and not the error, which holds a stack trace and, for a
      // timeout, a message which is different on every attempt
      if (client.state === ClientState.connected)
        f.update(null, (err as MqttErr)?.reason != null ? err.msg : err.typeof.qname)
      return err
    }
  }

  ** Nobody is waiting on a subscribe, so new failures go to the ext log
  ** as one summary, not a line per topic filter or per retry
  private Void logFailures(MqttFilter[] all)
  {
    failed := all.findAll |f| { f.isNewFailure }
    if (failed.isEmpty) return
    log.err("Subscribe failed for ${failed.size} of ${all.size} filters [${dis}], first: ${failed.first.filter} ${failed.first.state.err}")
  }

  private Obj? onUnsub(MqttSubscription sub)
  {
    // the broker and client track one subscription per filter, so keep
    // it while another subscription on this connector still uses it
    remaining := filters
    if (remaining.any |f| { f.filter == sub.filter }) return null

    try
    {
      open.client.unsubscribe(sub.filter).get
      return null
    }
    catch (Err err)
    {
      trace.asLog.err("Failed to unsubscribe filter: $sub.filter", err)
      throw err
    }
    finally
    {
      // close the subscription pin with the last subscription
      if (remaining.isEmpty) closePin("mqtt.sub")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Housekeeping
//////////////////////////////////////////////////////////////////////////

  override Void onHouseKeeping()
  {
    if (client == null) { setConnData(null); return }

    // retry topic filters which are not subscribed at the open retry frequency
    all  := filters
    due  := Duration.nowTicks - conn.openRetryFreq.ticks
    if (all.any |f| { !f.isSubscribed && (f.state?.ticks ?: 0) < due }) onResub(all)

    setConnData(toDetails(all))
  }

  ** Client and subscription state to show for the connector details
  private Str toDetails(MqttFilter[] all)
  {
    subscribed := 0
    failed     := 0
    lines      := StrBuf()
    all.each |f|
    {
      state := f.state
      if (state?.qos != null) { subscribed++; return }
      if (state?.err == null) return

      // only name the first few topic filters which failed
      failed++
      if (failed <= 10) lines.add("Failed: ${f.filter}: ${state.err}\n")
    }
    if (failed > 10) lines.add("Failed: ${failed - 10} more\n")

    pending := all.size - subscribed - failed
    return StrBuf().add(client.debugClient)
      .add("\n\nSubscriptions\n-------------\n")
      .add("Filters: ${all.size} [${subscribed} subscribed, ${failed} failed, ${pending} pending]\n")
      .add(lines.toStr)
      .toStr
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
