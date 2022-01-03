//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  13 Apr 2021   Matthew Giannini  Creation
//

**
** Packets that can be [persisted]`ClientPersistence` must implement this mixin.
**
mixin PersistablePacket
{
  ** Get the version of the packet that was persisted.
  abstract MqttVersion packetVersion()

  ** Get an `sys::InStream` for reading a packet that was encoded
  ** according to specified `packetVersion`.
  abstract InStream in()
}
