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

  ** Make for a reason code. The details are the reason
  ** string the server gave, if any.
  new makeReason(ReasonCode reason, Err? cause := null, Str? details := null)
    : super.make(details == null ? "Reason: ${reason}" : "Reason: ${reason} (${details})", cause)
  {
    this.reason = reason
  }

  const ReasonCode? reason := null
}
