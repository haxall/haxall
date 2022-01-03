//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  05 Apr 2021   Matthew Giannini  Creation
//

**************************************************************************
** MqttErr
**************************************************************************

**
** General MQTT error.
**
const class MqttErr : Err
{
  new make(Str msg := "", Err? cause := null) : super(msg, cause)
  {
  }

  new makeReason(ReasonCode reason, Err? cause := null)
    : super.make("Reason: ${reason}", cause)
  {
    this.reason = reason
  }

  const ReasonCode? reason := null
}

**************************************************************************
** MalformedPacketErr
**************************************************************************

**
** A malformed packet error occurs when the decoder fails to decode
** a packet or detects invalid state between the fields in a packet.
**
const class MalformedPacketErr : MqttErr
{
  new make(Str msg := "", Err? cause := null) : super(msg, cause)
  {
  }
}