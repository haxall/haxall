//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  01 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**************************************************************************
** Publish
**************************************************************************

**
** PUBLISH - publish message
**
internal const class Publish : PersistableControlPacket
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(|This| f)
  {
    f(this)
  }

  new makeFields(Str topicName, Message msg)
  {
    this.topicName = topicName
    this.msg       = msg
  }

  new decode(Int flags, InStream in, MqttVersion version)
  {
    this.isDup.val = flags.and(0x08) != 0
    qos           := QoS.vals[flags.shiftr(1).and(0x03)]
    retain        := flags.and(0x01) != 0
    this.topicName = readUtf8(in)
    if (qos !== QoS.zero)
    {
      this.packetId.val = readByte2(in)
    }
    props   := version.is5 ? readProps(in) : Properties()
    payload := in.avail == 0 ? empty : in.readAllBuf

    this.msg = Message(payload, qos, retain) {
      it.utf8Payload     = props.utf8Payload
      it.expiryInterval  = props.messageExpiryInterval
      it.topicAlias      = props[Property.topicAlias]
      it.responseTopic   = props[Property.responseTopic]
      it.correlationData = props[Property.correlationData]
      it.contentType     = props[Property.contentType]
      it.userProps       = props.userProps
      it.subscriptionIds = props.subscriptionIds
    }
  }

  override const PacketType type := PacketType.publish

//////////////////////////////////////////////////////////////////////////
// Publish
//////////////////////////////////////////////////////////////////////////

  override Void markDup() { isDup.val = true }

  private const AtomicBool isDup := AtomicBool(false)

  ** The topic name to publish to
  const Str topicName

  ** The application message
  const Message msg

  ** Convenience to get the message payload
  Buf payload() { msg.payload }

  ** Convenience to get the message QoS
  QoS qos() { msg.qos }

  ** Convenience to get the message retention flag
  Bool retain() { msg.retain }

  protected override Int packetFlags()
  {
    flags := 0
    // dup flags must be zero if QoS 0
    if (isDup.val && qos !== QoS.zero) flags = flags.or(0x08)
    flags = flags.or(qos.ordinal.shiftl(1))
    if (retain) flags = flags.or(0x01)
    return flags
  }

  protected override Buf variableHeaderAndPayload(MqttVersion version)
  {
    Topic.validateName(topicName)

    // variable header
    buf := Buf(topicName.size + 4 + msg.payload.size)
    writeUtf8(topicName, buf)
    if (qos !== QoS.zero)
    {
      // the packet identifier is only present for QoS 1 and 2 packets
      writeByte2(this.pid, buf)
    }
    if (version.is5)
    {
      writeProps(msg.props, buf)
    }

    // payload
    buf.writeBuf(msg.payload)

    return buf.flip
  }
}

**************************************************************************
** QoS
**************************************************************************

**
** MQTT Quality-of-Service levels
**
** - At Most Once (fire-and-forget): QoS 0
** - At Least Once: QoS 1
** - Exactly Once: QoS 2
**
enum class QoS
{
  zero, one, two

  Bool isZero() { this === QoS.zero }
}

**************************************************************************
** PubFlowPacket
**************************************************************************

**
** A packet used in QoS 1 and 2 acknowledgement flows
**
internal abstract const class PubFlowPacket : PersistableControlPacket
{
  new make(Int pid, |This|? f := null)
  {
    f?.call(this)
    this.packetId.val = pid
  }

  new decode(InStream in, MqttVersion version)
  {
    this.packetId.val = readByte2(in)
    if (version.is5)
    {
      if (in.avail > 0) this.reason = ReasonCode.fromCode(readByte(in), this.type)
      if (in.avail > 0) this.props  = readProps(in)
    }
  }

  ** The ack reason code
  const ReasonCode reason := ReasonCode.success

  ** The properties for this ack
  const Properties props := Properties()

  protected override Buf variableHeaderAndPayload(MqttVersion version)
  {
    buf := Buf(16)
    writeByte2(this.pid, buf)
    if (version.is5)
    {
      writeByte(reason.code, buf)
      writeProps(props, buf)
    }
    return buf.flip
  }

  Bool isErr() { reason.isErr }

  override Str toStr() { "${typeof.name}(id=$pid, code=$reason)" }
}

**************************************************************************
** PubAck
**************************************************************************

**
** PUBACK - publish acknowledgement
**
internal const class PubAck : PubFlowPacket
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Create a packet to acknowledge a QoS 1 PUBLISH with the given packet identifier
  new make(Int pid, |This|? f := null) : super.make(pid, f)
  {
  }

  new decode(InStream in, MqttVersion version) : super.decode(in, version)
  {
  }

  override const PacketType type := PacketType.puback
}

**************************************************************************
** PubRec
**************************************************************************

**
** PUBREC - Publish received (QoS 2 publish received, part 1)
**
internal const class PubRec : PubFlowPacket
{
  ** Create a packet to acknowledge a QoS 2 PUBLISH with the given packet identifier
  new make(Int pid, |This|? f := null) : super.make(pid, f)
  {
  }

  new decode(InStream in, MqttVersion version) : super.decode(in, version)
  {
  }

  override const PacketType type := PacketType.pubrec
}

**************************************************************************
** PubRel
**************************************************************************

**
** PUBREL - Publish release (QoS 2 publish received, part 2)
**
internal const class PubRel : PubFlowPacket
{
  ** Create a packet to acknowledge a QoS 2 PUBLISH with the given packet identifier
  new make(Int pid, |This|? f := null) : super.make(pid, f)
  {
  }

  new decode(Int flags, InStream in, MqttVersion version) : super.decode(in, version)
  {
    if (flags != packetFlags) throw MqttErr("Invalid packet flags: ${flags.toRadix(2,8)}")
  }

  override const PacketType type := PacketType.pubrel

  protected override Int packetFlags() { 0x02 }
}

**************************************************************************
** PubComp
**************************************************************************

**
** PUBCOMP - Publish complete (QoS 2 publish received part 3)
**
internal const class PubComp : PubFlowPacket
{
  ** Create a packet to acknowledge a QoS 2 PUBLISH with the given packet identifier
  new make(Int pid, |This|? f := null) : super.make(pid, f)
  {
  }

  new decode(InStream in, MqttVersion version) : super.decode(in, version)
  {
  }

  override const PacketType type := PacketType.pubcomp
}