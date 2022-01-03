//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  13 May 2021   Matthew Giannini  Creation
//

**
** MQTT constants
**
mixin MqttConst
{
  ** This session expiry interval indicates that the server should close the session
  ** when the network connection is closed.
  static const Duration sessionExpiresOnClose := 0sec

  ** This session expiry interval indicates that the server should never expire
  ** the session.
  static const Duration sessionNeverExpires := Duration(0xffff_ffff.toStr + "sec")

  ** MQTT minimum allowable packet identifier
  static const Int minPacketId := 1

  ** MQTT maximum allowable packet identifier
  static const Int maxPacketId := 65_535

  ** MQTT minimum allowable subscription identifier
  static const Int minSubId := 1

  ** MQTT maxium allowable subscription identifier
  static const Int maxSubId := 268_435_455
}
