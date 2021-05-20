//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  13 Apr 2021   Matthew Giannini  Creation
//

**
** Defines the API for the client persistance layer. The persistance
** layer is used to store unacknowledged QoS 1 and QoS 2 messages.
**
const mixin ClientPersistence
{
  ** Open the persistence layer for storing/retrieving messages for the
  ** client with the given client identifier.
  abstract Void open(Str clientId)

  ** Store a packet associated with the given key.
  abstract Void put(Str key, PersistablePacket packet)

  ** Iterate all stored messages.
  abstract Void each(|PersistablePacket packet, Str key| f)

  ** Remove the stored packet with the given key. If the key does not exist
  ** it is a no-op.
  abstract Void remove(Str key)

  ** Return 'true' if there is a packet stored with the given key; 'false' otherwise.
  abstract Bool containsKey(Str key)

  ** Close the persistence store.
  abstract Void close()

  ** Clear all stored messages for the given client identifier.
  abstract Void clear(Str clientId)
}
