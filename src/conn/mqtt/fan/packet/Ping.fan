//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  07 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**************************************************************************
** PINGREQ
**************************************************************************

**
** PINGREQ - ping request
**
internal const class PingReq : ControlPacket
{
  public static const PingReq defVal := PingReq()

  new make() { }

  override const PacketType type := PacketType.pingreq

  protected override Buf variableHeaderAndPayload(MqttVersion version) { empty }
}

**************************************************************************
** PINGRESP
**************************************************************************

**
** PINGRESP - ping response
**
internal const class PingResp : ControlPacket
{
  public static const PingResp defVal := PingResp()

  new make() { }

  override const PacketType type := PacketType.pingresp

  protected override Buf variableHeaderAndPayload(MqttVersion version) { empty }
}