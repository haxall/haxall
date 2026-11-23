//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  07 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**
** DISCONNECT - disconnect notification
**
internal const class Disconnect : ControlPacket
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(|This|? f := null)
  {
    f?.call(this)
  }

  new makeFields(ReasonCode reason, Properties props := Properties())
  {
    this.reason = reason
    this.props  = props
  }

  new decode(InStream in, MqttVersion version)
  {
    // 3.1.1 has no variable header; in 5.0 the reason code
    // and properties may be omitted
    if (version.is311) return
    if (in.avail > 0) this.reason = ReasonCode.fromCode(readByte(in), this.type, false) ?: ReasonCode.unspecified_error
    if (in.avail > 0) this.props  = readProps(in)
  }

  override const PacketType type := PacketType.disconnect

//////////////////////////////////////////////////////////////////////////
// Disconnect
//////////////////////////////////////////////////////////////////////////

  ** The disconnect reason code
  const ReasonCode reason := ReasonCode.normal_disconnection

  ** The disconnect properties
  const Properties props := Properties()

  protected override Buf variableHeaderAndPayload(MqttVersion version)
  {
    if (version.is311) return empty

    buf := Buf(32)
    writeByte(reason.code, buf)
    writeProps(props, buf)
    return buf.flip
  }
}