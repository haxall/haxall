//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  26 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**************************************************************************
** Unsubscribe
**************************************************************************

**
** UNSUBSCRIBE - unsubscribe from topics
**
internal const class Unsubscribe : ControlPacket
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new makeFields(Str[] topics)
  {
    this.topics = topics
    checkFields
  }

  new decode(Int flags, InStream in, MqttVersion version)
  {
    if (flags != packetFlags) throw MqttErr("Invalid packet flags: ${flags.toRadix(2,0)}")

    // variable header
    this.packetId.val = readByte2(in)
    if (version.is5)
    {
      this.props = readProps(in)
    }

    // payload
    acc := Str[,]
    while (in.avail > 0) { acc.add(readUtf8(in)) }
    this.topics = acc

    checkFields
  }

  private Void checkFields()
  {
    if (topics.isEmpty)
      throw ArgErr("Must specify at least one topic")
  }

  override const PacketType type := PacketType.unsubscribe

//////////////////////////////////////////////////////////////////////////
// Unsubscribe
//////////////////////////////////////////////////////////////////////////

  const Properties props := Properties()

  const Str[] topics

  protected override Int packetFlags() { 0x02 }

  protected override Buf variableHeaderAndPayload(MqttVersion version)
  {
    topics.each { Topic.validateFilter(it) }

    // variable header
    buf := Buf(256)
    writeByte2(this.pid, buf)
    if (version.is5)
    {
      writeProps(this.props, buf)
    }

    // payload
    topics.each |topic| { writeUtf8(topic, buf) }

    return buf.flip
  }

}

**************************************************************************
** UnsubAck
**************************************************************************

internal const class UnsubAck : ControlPacket
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new decode(InStream in, MqttVersion version)
  {
    this.packetId.val = readByte2(in)
    if (version.is5)
    {
      this.props = readProps(in)

      acc := ReasonCode[,]
      while (in.avail > 0) { acc.add(ReasonCode.fromCode(readByte(in), this.type)) }
      this.reasons = acc
    }
  }

  override const PacketType type := PacketType.unsuback

//////////////////////////////////////////////////////////////////////////
// UnsubAck
//////////////////////////////////////////////////////////////////////////

  const Properties props := Properties()

  const ReasonCode[] reasons := ReasonCode#.emptyList

  protected override Buf variableHeaderAndPayload(MqttVersion version)
  {
    buf := Buf(2)

    // variable header
    writeByte2(this.pid, buf)

    if (version.is5)
    {
      // variable header
      writeProps(this.props, buf)

      // payload only in MQTT >= 5
      reasons.each |reason| { writeByte(reason.code, buf) }
    }

    return buf.flip
  }

  override Str toStr() { "UnsubAck(id=$pid)" }
}