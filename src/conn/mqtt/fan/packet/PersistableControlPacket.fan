//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  13 Apr 2021   Matthew Giannini  Creation
//

using concurrent

internal const abstract class PersistableControlPacket : ControlPacket, PersistablePacket
{
  virtual Void markDup() { }

  override MqttVersion packetVersion()
  {
    packetVersionRef.val ?: throw MqttErr("Illegal State: packet version not set on ${typeof}")
  }
  internal const AtomicRef packetVersionRef := AtomicRef(null)

  override InStream in()
  {
    buf := Buf()
    encode(buf.out, packetVersion)
    return buf.flip.in
  }

  static PersistableControlPacket fromPersistablePacket(PersistablePacket p)
  {
    ControlPacket.readPacket(p.in, p.packetVersion)
  }
}
