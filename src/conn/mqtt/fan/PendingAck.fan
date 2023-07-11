//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  14 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**************************************************************************
** PendingAck
**************************************************************************

**
** Information about a packet requiring acknowledgement
**
internal const class PendingAck
{
  new make(ControlPacket packet, Str? persistKey := null)
  {
    this.created    = Duration.nowTicks
    this.packetId   = packet.pid
    this.persistKey = persistKey

    // only stash the request if the packet was not persisted
    if (persistKey == null) stash["req"] = packet
  }

  new clone(PendingAck source, Str persistKey)
  {
    this.persistKey = persistKey
    this.packetId   = source.packetId
    this.created    = source.created
    this.resp       = source.resp
    this.stash      = source.stash
  }

  ** The packet identifier we are waiting to be acknowledged.
  const Int packetId

  ** The key used to persist the request packet.
  ** Will be null if the packet wasn't persisted.
  const Str? persistKey := null

  ** Ticks when this request was created
  const Int created

  ** Get the age of this pending packet
  Duration age() { Duration(Duration.nowTicks - created) }

  ** Ticks when this request was last sent to the broker
  private const AtomicInt lastSent := AtomicInt(0)

  ** Update the last sent timestamp and return this
  This touch()
  {
    lastSent.val = Duration.nowTicks
    return this
  }

  ** Future that will be completed when the response arrives
  ** or housekeeping determines an error/timeout
  const Future resp := Future.makeCompletable

  ** Have we received the connack response
  Bool isComplete() { resp.status.isComplete }

  ** Return if this packet needs a retry based on the timeout threshold
  Bool isRetryNeeded(Duration threshold)
  {
    if (isComplete) return false
    return (Duration(Duration.nowTicks - lastSent.val) > threshold)
  }

  ControlPacket? get(Bool checked := true)
  {
    if (isComplete) return resp.get
    if (checked) throw MqttErr("Ack not received for packet ${packetId}")
    return null
  }

  ** Additional data that can be stashed on the pending ack.
  const ConcurrentMap stash := ConcurrentMap(2)

  ** Get the stashed request
  ControlPacket? req(Bool checked := true)
  {
    req := stash["req"] as ControlPacket
    if (req != null) return req
    if (checked) throw MqttErr("Request not stashed")
    return null
  }
}

**************************************************************************
** PendingConn
**************************************************************************

**
** Information about a pending CONNECT request
**
internal const class PendingConn : PendingAck
{
  new make(Connect connect) : super.make(connect, null)
  {
    this.connect = connect
  }

  ** The connect packet we are waiting to receive CONNACK for
  const Connect connect

  ConnAck? connack(Bool checked := true) { get(checked) }
}