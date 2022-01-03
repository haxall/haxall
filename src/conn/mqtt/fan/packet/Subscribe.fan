//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  23 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**************************************************************************
** Subscribe
**************************************************************************

**
** SUBSCRIBE - subscribe to topics
**
internal const class Subscribe : ControlPacket
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new makeFields(Str[] topics, Int[] opts, Properties props := Properties())
  {
    this.topics = topics
    this.opts   = opts
    this.props  = props
    checkFields
  }

  new decode(Int flags, InStream in, MqttVersion version)
  {
    // TODO:FIXIT - throw a better error
    if (flags != packetFlags) throw MqttErr("Invalid packet flags: ${flags.toRadix(2, 8)}")

    if (version.is5) throw UnsupportedErr("TODO: $version")

    // variable header
    this.packetId.val = readByte2(in)
    if (version.is5)
    {
      this.props = readProps(in)
    }

    // payload
    t := Str[,]
    o := Int[,]
    while (in.avail != 0)
    {
      t.add(readUtf8(in))
      o.add(readByte(in))
    }
    this.topics = t
    this.opts   = o

    checkFields
  }

  private Void checkFields()
  {
    if (topics.size != opts.size)
      throw ArgErr("# topics ($topics.size) != # options ($opts.size)")
  }

  override const PacketType type := PacketType.subscribe

//////////////////////////////////////////////////////////////////////////
// Subscribe
//////////////////////////////////////////////////////////////////////////

  const Str[] topics

  const Int[] opts

  const Properties props := Properties()

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
    topics.each |topic, i|
    {
      writeUtf8(topic, buf)
      writeByte(opts[i], buf)
    }

    return buf.flip
  }
}

**************************************************************************
** SubAck
**************************************************************************

**
** SUBACK - Subscribe acknowledgement
**
internal const class SubAck : ControlPacket
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new makeFields(ReasonCode[] returnCodes)
  {
    this.returnCodes = returnCodes
    checkFields
  }

  new decode(InStream in, MqttVersion version)
  {
    // variable header
    this.packetId.val = readByte2(in)
    if (version.is5)
    {
      this.props = readProps(in)
    }

    // payload
    acc := ReasonCode[,]
    while (in.avail > 0)
    {
      acc.add(ReasonCode.fromCode(readByte(in), this.type))
    }
    this.returnCodes = acc
    checkFields
  }

  private Void checkFields()
  {
    if (returnCodes.isEmpty)
      throw ArgErr("There must be at least one return code")
  }

  override const PacketType type := PacketType.suback

//////////////////////////////////////////////////////////////////////////
// SubAck
//////////////////////////////////////////////////////////////////////////

  const Properties props := Properties()

  const ReasonCode[] returnCodes := ReasonCode#.emptyList

  protected override Buf variableHeaderAndPayload(MqttVersion version)
  {
    // variable header
    buf := Buf(returnCodes.size)
    writeByte2(this.pid, buf)
    if (version.is5)
    {
      writeProps(this.props, buf)
    }

    // payload
    returnCodes.each |reason| { writeByte(reason.code, buf) }
    return buf.flip
  }

  override Str toStr() { "SubAck(id=$pid)" }
}
