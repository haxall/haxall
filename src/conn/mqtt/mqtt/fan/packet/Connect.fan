//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  26 Mar 2021   Matthew Giannini  Creation
//

using concurrent

**************************************************************************
** Connect
**************************************************************************

**
** CONNECT - connection request
**
internal const class Connect : ControlPacket
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(|This| f)
  {
    f(this)
  }

  override const PacketType type := PacketType.connect

//////////////////////////////////////////////////////////////////////////
// Connect
//////////////////////////////////////////////////////////////////////////

  const MqttVersion version

  const Bool cleanSession

  const Duration keepAlive

  const Str clientId

  const Publish? willPublish := null

  const Str? username := null

  const Buf? password := null

  const Properties props := Properties()

//////////////////////////////////////////////////////////////////////////
// Encode
//////////////////////////////////////////////////////////////////////////

  protected override Buf variableHeaderAndPayload(MqttVersion version)
  {
    buf := Buf(128)
    variableHeader(buf, version)
    payload(buf, version)
    return buf.flip
  }

  private Void variableHeader(Buf buf, MqttVersion version)
  {
    writeUtf8("MQTT", buf)
    writeByte(version.code, buf)
    writeByte(flags, buf)
    writeByte2(keepAlive.toSec, buf)
    if (version.is5)
    {
      writeProps(props, buf)
    }
  }

  private Void payload(Buf buf, MqttVersion version)
  {
    writeUtf8(clientId, buf)
    if (hasWill)
    {
      if (version.is5) writeProps(willPublish.msg.props, buf)
      writeUtf8(willPublish.topicName, buf)
      writeBin(willPublish.msg.payload, buf)
    }
    if (username != null) writeUtf8(username, buf)
    if (password != null) writeBin(password, buf)
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  This validate()
  {
    if (version.is311)
    {
      if (clientId.isEmpty && !cleanSession)
        throw MqttErr("ClientId is zero bytes, but clean session not requested [MQTT-3.1.3-7] ($version)")
      if (username == null && password != null)
        throw MqttErr("Cannot set a password without a username [MQTT-3.1.2-22] ($version)")
    }
    return this
  }

  ** Is a will publish configured
  Bool hasWill() { willPublish != null }

  internal Int flags()
  {
    flags := 0
    if (username != null) flags = flags.or(0x80)
    if (password != null) flags = flags.or(0x40)
    if (hasWill)
    {
      if (willPublish.retain) flags = flags.or(0x20)
      flags = flags.or(willPublish.qos.ordinal.shiftl(3))
      flags = flags.or(0x04)
    }
    if (cleanSession) flags = flags.or(0x02)
    return flags
  }
}

**************************************************************************
** ConnAck
**************************************************************************

**
** CONNACK - connection acknowledgement
**
internal const class ConnAck : ControlPacket
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(|This| f)
  {
    f(this)
  }

  new decode(InStream in, MqttVersion version)
  {
    ackFlags := readByte(in)
    this.isSessionPresent = ackFlags.and(0x01) != 0
    if (ackFlags.and(0b1111_1110) != 0) throw MqttErr("Invalid ack flags: ${ackFlags.toRadix(2,8)}")
    this.reason = ReasonCode.fromCode(readByte(in), this.type)
    if (version.is5)
    {
      this.props = readProps(in)
    }
  }

  override const PacketType type := PacketType.connack

//////////////////////////////////////////////////////////////////////////
// ConnAck
//////////////////////////////////////////////////////////////////////////

  ** Does the server have stored session state for this connection
  const Bool isSessionPresent

  ** The connack reason code
  const ReasonCode reason

  ** The connack properties
  const Properties props := Properties()

  protected override Buf variableHeaderAndPayload(MqttVersion version)
  {
    buf   := Buf(16)
    flags := 0
    if (isSessionPresent) flags = flags.or(0x01)
    writeByte(flags, buf)
    writeByte(reason.code, buf)
    if (version.is5)
    {
      writeProps(props, buf)
    }
    return buf.flip
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  Bool isSuccess() { reason === ReasonCode.success }

}