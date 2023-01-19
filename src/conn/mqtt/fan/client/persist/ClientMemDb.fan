//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  13 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**************************************************************************
** ClientMemDb
**************************************************************************

**
** Stores messages in-memory for Qos 1 and QoS 2 messages.
**
const class ClientMemDb : ClientPersistence
{
  new make() { }

  private const ConcurrentMap sessions := ConcurrentMap()
  private const AtomicBool isOpened := AtomicBool(false)

  private ClientMemSession? session(Bool checked := true)
  {
    if (checked) checkOpened
    return (sessionRef.val as Unsafe)?.val
  }
  private const AtomicRef sessionRef := AtomicRef(null)

  override Void open(Str clientId)
  {
    if (isOpened.val) throw MqttErr("Already opened")
    session := (ClientMemSession)sessions.getOrAdd(clientId, ClientMemSession(clientId))
    sessionRef.val = Unsafe(session)
    isOpened.val = true
  }

  override PersistablePacket? get(Str key)
  {
    session.get(key)
  }

  override Void put(Str key, PersistablePacket packet)
  {
    session.put(key, packet)
  }

  override Void each(|PersistablePacket packet, Str key| f)
  {
    // iterate the stored packets *in order* !!!
    session.keys.each |key|
    {
      f(session.packets[key], key)
    }
  }

  override Void remove(Str key)
  {
    session.remove(key)
  }

  override Bool containsKey(Str key)
  {
    session.packets.containsKey(key)
  }

  override Void close()
  {
    checkOpened
    isOpened.val   = false
    sessionRef.val = null
  }

  override Void clear(Str clientId)
  {
    (sessions.get(clientId) as ClientMemSession)?.clear
  }

  override Str toStr()
  {
    if (!isOpened.val) return "[closed]"

    return "[open] [$session.clientId] [# keys: ${session.keys.size}]"
  }

  private Void checkOpened()
  {
    if (!isOpened.val) throw MqttErr("Not opened")
  }
}

**************************************************************************
** ClientMemSession
**************************************************************************

internal const class ClientMemSession
{
  new make(Str clientId) { this.clientId = clientId }

  const Str clientId

  PersistablePacket? get(Str key)
  {
    packets.get(key)
  }

  Void put(Str key, PersistablePacket packet)
  {
    packets[key] = packet
  }

  Void remove(Str key)
  {
    packets.remove(key)
  }

  Void clear()
  {
    packets.clear
  }

  Str[] keys() { packets.keys(Str#) }
  const ConcurrentMap packets := ConcurrentMap()
}

