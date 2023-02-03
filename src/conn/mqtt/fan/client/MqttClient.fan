//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  05 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**
** MQTT Client (Asynchronous)
**
const class MqttClient : Actor, MqttConst
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(ClientConfig config, Log log := Log.get(config.pool.name))
    : super.makeCoalescing(config.pool, |Obj? msg->Obj?| {
        if (msg isnot ActorMsg) return null
        return ((ActorMsg)msg).id == "shutdown" ? "shutdown" : null
      }, null, null)
  {
    this.config = config
    this.log    = log

    this.packetReader  = PacketReaderActor(this)
    this.packetWriter  = PacketWriterActor(this)
    this.listeners     = ClientListeners(this)
  }

  ** Client configuration
  const ClientConfig config

  ** Client log
  const Log log

  ** The current connection state
  ClientState state() { stateRef.val }

//////////////////////////////////////////////////////////////////////////
// Internal Fields
//////////////////////////////////////////////////////////////////////////

  ** Housekeeping message
  internal static const ActorMsg housekeeping := ActorMsg("housekeeping")

  internal const PacketReaderActor packetReader
  internal const PacketWriterActor packetWriter

  ** Connection state with the broker
  internal const AtomicRef stateRef := AtomicRef(ClientState.disconnected)

  ** Underlying network transport
  internal MqttTransport? transport() { (transportRef.val as Unsafe)?.val }
  internal const AtomicRef transportRef := AtomicRef(Unsafe(null))

  ** Ticks when the last packet was sent
  internal const AtomicInt lastPacketSent := AtomicInt(0)

  ** Ticks when the last packet was received
  internal const AtomicInt lastPacketReceived := AtomicInt(0)

  ** Number of qos 1 or qos 2 message the server is willing
  ** to allow to be outstanding. This value starts out at the max
  ** and is decremented each time we send a packet requiring acks.
  ** The quota is then increased when we receive the ack.
  internal const AtomicInt quota := AtomicInt(Int.maxVal)

  ** Subscription manager
  internal ClientSubMgr subMgr() { subMgrRef.val }
  private const Unsafe subMgrRef := Unsafe(ClientSubMgr(this))

  ** Client listeners
  internal const ClientListeners listeners

  ** Is the client terminated
  Bool isTerminated() { terminated.val }
  private const AtomicBool terminated := AtomicBool(false)

//////////////////////////////////////////////////////////////////////////
// Internal Pending Ack State and Utils
//////////////////////////////////////////////////////////////////////////

  ** The pending connect request. Will be completed when connack is received
  ** or timeout is determined by housekeeping.
  internal PendingConn pendingConnect() { pendingConnectRef.val }
  internal const AtomicRef pendingConnectRef := AtomicRef(notConnected)

  internal Str clientId() { clientIdRef.val }
  internal const AtomicRef clientIdRef := AtomicRef()

  private const ConcurrentMap pendingAcks := ConcurrentMap()
  private const AtomicInt lastPacketId := AtomicInt(maxPacketId)

  ** Find the next free packet identifier. It is not actually consumed
  ** until `sendPacket()` is called. So that should all happen while
  ** processing the same actor message.
  internal Int nextPacketId()
  {
    for (i := 0; i < maxPacketId; ++i)
    {
      id := lastPacketId.incrementAndGet
      if (id > maxPacketId)
      {
        // rollover
        id = minPacketId
        lastPacketId.val = id
      }
      if (pendingAcks[id] == null) return id
    }
    throw MqttErr("No available packet identifiers: ${pendingAcks.size}")
  }

  ** Choke-point to send a packet that we expect to receive an ack for.
  internal PendingAck? sendPacket(ControlPacket packet, PendingAck pending)
  {
    // consume the packet identifier by adding to pending acks map
    pendingAcks[packet.pid] = pending.touch

    // send (non-blocking)
    packetWriter.send(packet)

    return pending
  }

  ** Free the packet identifier associated with this packet by removing
  ** it from the pending acks map and returning the pending ack associated with
  ** that pid.
  private PendingAck? freePending(Obj arg)
  {
    Int? pid := arg as Int
    if (pid == null) pid = ((ControlPacket)arg).pid
    return pendingAcks.remove(pid)
  }

  ** Do all required actions to update state when a pending ack is finished
  internal Void finishPending(PendingAck pending)
  {
    // ensure it is freed
    freePending(pending.packetId)

    // only need this cleanup if the packet was persisted (publish)
    if(pending.persistKey != null)
    {
      // discard state
      config.persistence.remove(pending.persistKey)

      // update quoata
      quota.increment
    }
  }

//////////////////////////////////////////////////////////////////////////
// Client
//////////////////////////////////////////////////////////////////////////

  ** Configure the client to auto-reconnect and return this
  This enableAutoReconnect(Duration initialDelay := 1sec, Duration maxDelay := 2min)
  {
    addListener(DefaultAutoReconnect(this) {
      it.initialDelay = initialDelay.max(500ms)
      it.maxDelay = maxDelay.max(1sec)
    })
  }

  ** Add a `ClientListener` and return this
  This addListener(ClientListener listener)
  {
    listeners.addListener(listener)
    return this
  }

  ** Open a connection to the server using the given configuration.
  **
  ** Returns a future that will be completed:
  ** 1. when the 'CONNACK' is received
  ** 2. with an error if the connect times out
  Future connect(ConnectConfig config := ConnectConfig())
  {
    // connect returns a future that will be completed when the connack is received
    send(ActorMsg("connect", config)).get
  }

  ** Publish a message to the given topic. See `publishWith` to use a "fluent"
  ** API for publishing.
  **
  ** Returns a future that will be completed when the message is confirmed
  ** to be received by the server accoring to the specified QoS.
  Future publish(Str topic, Message msg)
  {
    // publish returns a future that will be completed according to its QoS
    sendWhenComplete(pendingConnect.resp, ActorMsg("publish", Publish(topic, msg))).get
  }

  ** Get a publish builder to configure and send your request
  PubSend publishWith() { PubSend(this) }

  ** Subscribe to the given topic filter. You are responsible for setting the
  ** option flags correctly. See `subscribeWith` to use a "fluent" API for
  ** subscribing.
  **
  ** Return a future that will be completed when the 'SUBACK' is received.
  Future subscribe(Str filter, Int opts, SubscriptionListener listener)
  {
    sub := Subscribe([filter], [opts])
    msg := ActorMsg("subscribe", sub, Unsafe(listener))
    return sendWhenComplete(pendingConnect.resp, msg).get
  }

  ** Get a subscription builder to configure and send your request.
  SubSend subscribeWith() { SubSend(this) }

  ** Unsubscribe from the given topic filter.
  **
  ** Returns a future that will be completed when the 'UNSUBACK' is received.
  Future unsubscribe(Str topicFilter)
  {
    unsub := Unsubscribe([topicFilter])
    msg   := ActorMsg("unsubscribe", unsub)
    return sendWhenComplete(pendingConnect.resp, msg).get
  }

  ** Disconnect from the server.
  **
  ** Returns a future that will be completed after the 'DISCONNECT' message is actually
  ** sent to the server.
  Future disconnect()
  {
    sendWhenComplete(pendingConnect.resp, ActorMsg("disconnect", Disconnect()))
  }

  ** Disconnect and terminate all resources used by the client. After this method
  ** is called the client can no longer be used. When you are done with the
  ** client it is strongly recommended to call this method to clean up all resources.
  This terminate()
  {
    this.terminated.val = true
    try
    {
      this.onShutdown
    }
    finally
    {
      config.pool.stop
    }
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Actor
//////////////////////////////////////////////////////////////////////////

  @NoDoc protected override Obj? receive(Obj? obj)
  {
    msg := obj as ActorMsg

    if (msg === housekeeping) return onHousekeeping(msg.a)

    try
    {
      switch (msg?.id)
      {
        case "connect":     return onConnect(msg.a)
        case "publish":     return onPublish(msg.a)
        case "subscribe":   return onSubscribe(msg.a, ((Unsafe)msg.b).val)
        case "unsubscribe": return onUnsubscribe(msg.a)
        case "disconnect":  return onDisconnect(msg.a)
        case "recv":        return onRecv(msg.a)
        case "shutdown":    return onShutdown(msg.a)
      }
    }
    catch (Err err)
    {
      // free any allocated packet identifier
      packet := msg.a as ControlPacket
      if (packet != null) this.freePending(packet)
      throw err
    }

    throw MqttErr("Unexpected message: $obj (${obj?.typeof})")
  }

//////////////////////////////////////////////////////////////////////////
// Outgoing
//////////////////////////////////////////////////////////////////////////

  private Future onConnect(ConnectConfig config)
  {
    ClientConnectHandler(this, config).run
  }

  private Obj? onPublish(Publish packet)
  {
    ClientPublishHandler(this).publish(packet)
  }

  private Obj? onSubscribe(Subscribe packet, SubscriptionListener listener)
  {
    subMgr.subscribe(packet, listener)
  }

  private Obj? onUnsubscribe(Unsubscribe packet)
  {
    subMgr.unsubscribe(packet)
  }

  private Obj? onPingReq(PingReq ping)
  {
    packetWriter.send(ping)
    return null
  }

  private Obj? onDisconnect(Disconnect disconnect)
  {
    try
    {
      // block a little to give a chance for the packet to get sent
      transition(ClientState.connected, ClientState.disconnecting)
      packetWriter.send(disconnect).get(10sec)
    }
    catch (Err ignore) {}
    finally this.onShutdown
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Incoming
//////////////////////////////////////////////////////////////////////////

  ** The packet reader actor invokes this callback whenever it receives
  ** a packet. This happens on the packet reader thread, so the packet
  ** should be handled quickly, or handed off to another actor to
  ** keep from blocking the reader.
  internal Void packetReceived(ControlPacket packet)
  {
    // update timestamp of last packet received
    lastPacketReceived.val = Duration.nowTicks

    // process message on client actor
    send(ActorMsg("recv", packet))
  }

  private Obj? onRecv(ControlPacket packet)
  {
    // these received messages are initiated by the server
    try
    {
      switch (packet.type)
      {
        case PacketType.connack:    return ClientConnAckHandler(this, packet).run
        case PacketType.pingresp:   return null
        case PacketType.publish:    return ClientPublishHandler(this).deliver(packet)
        case PacketType.pubrel:     return ClientPublishHandler(this).pubRel(packet)
        case PacketType.disconnect: return onReceiveDisconnect(packet)
      }
    }
    catch (Err err)
    {
      log.err("Failed to handle incoming packet: ${packet.type}", err)
      return null
    }

// log.err("TODO:FIXIT - don't handle acks")
// return null

    // we expect a pending ack for the remaining received messages
    pending := this.freePending(packet)
    if (pending == null) { debug("Unexpected: $packet.type"); return null }
    try
    {
      switch (packet.type)
      {
        case PacketType.puback:   ClientPublishHandler(this).pubAck(packet, pending)
        case PacketType.pubrec:   ClientPublishHandler(this).pubRec(packet, pending)
        case PacketType.pubcomp:  ClientPublishHandler(this).pubComp(packet, pending)
        case PacketType.suback:   subMgr.subAck(packet, pending)
        case PacketType.unsuback: subMgr.unsubAck(packet, pending)
      }

      // convenience to complete the ack if the handler didn't do it
      //
      // NOTE: QoS 2 message that the client sent will be completed
      // when the PUBCOMP is received (not when the intermediate PUBREC is received).
      // So we will not complete the future for a received PUBREC.
      if (packet.type !== PacketType.pubrec && !pending.isComplete)
        pending.resp.complete(packet)
    }
    catch (Err err)
    {
      log.err("Failed to process ack for $packet.type", err)
      if (!pending.isComplete) pending.resp.completeErr(err)
    }
    return null
  }

  ** The server sent the client a DISCONNECT message.
  ** For now, we just log it and shutdown the client.
  private Obj? onReceiveDisconnect(Disconnect disconnect)
  {
    log.info("Server requested DISCONNECT: ${disconnect.reason}")
    this.onShutdown
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Houskeeping
//////////////////////////////////////////////////////////////////////////

  private Obj? onHousekeeping(ActorMsg? msg)
  {
    // stop houskeeping if we are in a state where we can't send messages
    if (!canMessage) return null

    try
    {
      if (checkConnackReceived)
      {
        checkKeepAlive
        checkPending
      }
    }
    catch (Err err)
    {
      log.err("Houskeeping failed", err)
    }

    sendLater(1sec, housekeeping)
    return null
  }

  private Bool checkConnackReceived()
  {
    req := pendingConnect
    if (req.isComplete) return true
    else if ((Duration.nowTicks - req.created ) > config.mqttConnectTimeout.ticks)
    {
      // timeout
      req.resp.completeErr(
        this.onShutdown(TimeoutErr("CONNACK not received within ${config.mqttConnectTimeout.toLocale}"))
      )
    }
    return false
  }

  private Void checkKeepAlive()
  {
    // [MQTT5-3.2.2-21]
    server := pendingConnect.connack.props.get(Property.serverKeepAlive)
    ticks  := server == null
      ? pendingConnect.connect.keepAlive.ticks
      : Duration.fromStr("${server}sec").ticks

    if (ticks == 0) return

    // send a ping if we haven't sent a message within keepalive interval
    if ((Duration.nowTicks - lastPacketSent.val) > ticks)
      onPingReq(PingReq.defVal)
  }

  private Void checkPending()
  {
    if (pendingAcks.isEmpty) return

    pendingAcks.each |PendingAck pending| {
      if (pending.age > config.timeout)
      {
        // handle packet timeout
        log.debug("Packet ${pending.packetId} timed out after ${config.timeout.toLocale}")

        finishPending(pending)
        pending.resp.completeErr(TimeoutErr("No acknowledgement received for packet ${pending.packetId} after ${config.timeout.toLocale}"))
      }
      else if (config.maxRetry > 0 && pending.isRetryNeeded(config.retryInterval))
      {
        // handle packet retry
        log.debug("Retry packet ${pending.packetId}")

        p      := config.persistence.get(pending.persistKey)
        packet := PersistableControlPacket.fromPersistablePacket(p)

        packet.markDup
        sendPacket(packet, pending)
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Connection State
//////////////////////////////////////////////////////////////////////////

  ** Transition from the expected state to the new state. Throws an error
  ** if we are not in the expected state.
  internal ClientState transition(ClientState expected, ClientState to)
  {
    if (!stateRef.compareAndSet(expected, to))
    {
      throw MqttErr("Cannot transition $stateRef => $to : (expected $expected)")
    }
    return this.state
  }

  ** Is the client in a state where it can still send/receive messages
  internal Bool canMessage() { !isTerminated && state !== ClientState.disconnected }

  internal Void checkCanMessage()
  {
    if (!canMessage) throw MqttErr("Cannot send packets: $state [terminated=${isTerminated}]")
  }

  ** Force a shutdown of the client and return to a disconnected state.
  internal Future shutdown(Err? err := null)
  {
    send(ActorMsg("shutdown", err))
  }

  ** Should only be called inside actor (or on terminate)
  internal Err? onShutdown(Err? err := null)
  {
    if (state === ClientState.disconnected) return err

    // remember if this was client inititiated disconnect
    isClientDisconnect := state === ClientState.disconnecting

    // immediately force state to disconnected
    stateRef.val = ClientState.disconnected

    // log err
    if (err != null) log.err("Client disconnected", err)

    // close the underlying transport
    transport?.close
    transportRef.val = null

    // if clean session, clean up state
    try { config.persistence.close } catch (Err ignore) { }
    subMgr.close
    if (pendingConnect.connect.cleanSession)
    {
      config.persistence.clear(this.clientId)
      subMgr.clear
    }

    // try to complete all pending messages with an error
    pendingAcks.each |PendingAck pending| {
      try { pending.resp.completeErr(err ?: MqttErr("Client disconnected")) }  catch (Err x) {}
    }
    pendingAcks.clear

    // switch to disconnected error state
    if (!pendingConnect.isComplete) pendingConnect.resp.completeErr(err ?: MqttErr("Client disconnected"))
    pendingConnectRef.val = notConnected

    // notify listeners
    listeners.fireDisconnected(err, isClientDisconnect)

    return err
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  internal Void debug(Str msg, Err? err := null)
  {
    if (log.isDebug) log.debug(msg, err)
  }

  private static PendingConn notConnected()
  {
    p := PendingConn(ConnectConfig().packet("not-connected"))
    p.resp.completeErr(MqttErr("Disconnected"))
    return p
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  @NoDoc
  Str debugClient()
  {
    s := StrBuf()
    s.add("Mqtt Client\n")
     .add("-----------\n")
     .add("At: ${DateTime.now.toLocale}\n")
     .add("State: $stateRef.val [canMessage=${canMessage}]\n")
     .add("ConnAck Properties: ${pendingConnect.connack.props}\n")
     .add("Quota: ${quota}\n")
     .add("Pending Acks: ${pendingAcks.size}")
    return s.toStr
  }
}

**************************************************************************
** ClientState
**************************************************************************

**
** MQTT client connection state
**
enum class ClientState
{
  disconnected,
  connecting,
  connected,
  disconnecting
}
