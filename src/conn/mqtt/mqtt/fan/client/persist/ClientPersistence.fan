//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  13 Apr 2021   Matthew Giannini  Creation
//

const mixin ClientPersistence
{
  abstract Void open(Str clientId)

  abstract Void put(Str key, PersistablePacket packet)

  abstract Void each(|PersistablePacket packet, Str key| f)

  abstract Void remove(Str key)

  abstract Bool containsKey(Str key)

  abstract Void close()

  ** Can be called after persistence is closed to clear storage
  ** for most recently opened client id.
  abstract Void clear()
}
