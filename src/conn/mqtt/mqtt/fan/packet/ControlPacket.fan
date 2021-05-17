//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  26 Mar 2021   Matthew Giannini  Creation
//

using concurrent

**
** MQTT Control Packet
**
internal const abstract class ControlPacket : DataCodec
{
  new make()
  {
  }

  protected static const Buf empty := Buf(0)

  ** The packet type
  abstract PacketType type()

  ** Control flags for this packet (only lowest 4 bits are used)
  protected virtual Int packetFlags() { 0 }

  ** The packet identifier for this packet
  const AtomicInt packetId := AtomicInt(0)

  ** Convenience to get the packet identifier
  Int pid() { packetId.val }

  Void encode(OutStream out, MqttVersion version)
  {
    // get the encoded avariable header and payload
    varPay := variableHeaderAndPayload(version)

    // write the full control packet
    byte1 := type.ordinal.shiftl(4).or(packetFlags.and(0x0f))
    out.write(byte1)
    writeVbi(varPay.size, out)
    out.writeBuf(varPay)
  }

  protected abstract Buf variableHeaderAndPayload(MqttVersion version)

  static ControlPacket readPacket(InStream in, MqttVersion version)
  {
    byte1  := readByte(in)
    flags  := byte1.and(0x0f)
    code   := byte1.shiftr(4)
    type   := PacketType.vals.getSafe(code)
    len    := readVbi(in)
    varPay := in.readBufFully(null, len)
    switch (type)
    {
      case PacketType.connack:     return ConnAck(varPay.in, version)
      case PacketType.publish:     return Publish(flags, varPay.in, version)
      case PacketType.puback:      return PubAck(varPay.in, version)
      case PacketType.pubrec:      return PubRec(varPay.in, version)
      case PacketType.pubrel:      return PubRel(flags, varPay.in, version)
      case PacketType.pubcomp:     return PubComp(varPay.in, version)
      case PacketType.subscribe:   return Subscribe(flags, varPay.in, version)
      case PacketType.suback:      return SubAck(varPay.in, version)
      case PacketType.unsubscribe: return Unsubscribe(flags, varPay.in, version)
      case PacketType.unsuback:    return UnsubAck(varPay.in, version)
      case PacketType.pingresp:    return PingResp.defVal
      default: throw MqttErr("Unsupported packet type: ${code}")
    }
  }

  protected Void checkReservedFlags(Int flags)
  {
    if (flags != 0) throw MalformedPacketErr("Invalid packet flags: ${flags.toRadix(16,2)}")
  }
}

**************************************************************************
** PacketType
**************************************************************************

**
** Packet type enum. The ordinals correspond to the control value.
**
enum class PacketType
{
  reserved,
  connect,
  connack,
  publish,
  puback,
  pubrec,
  pubrel,
  pubcomp,
  subscribe,
  suback,
  unsubscribe,
  unsuback,
  pingreq,
  pingresp,
  disconnect,
  auth
}