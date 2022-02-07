//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   04 Feb 2022  Matthew Giannini  Creation
//

**
** RemoteSensor object
**
const class EcobeeRemoteSensor : EcobeeObj
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(|This| f) { f(this) }

  ** The unique sensor identifier. It is composed of deviceName + deviceId
  ** separated by colons (e.g. 'rs:100')
  override const Str? id

  ** The user assigned sensor name
  const Str? name

  ** The type of sensor
  const Str? type

  ** The unique 4-digit alphanumeric sensor code
  const Str? code

  ** This flag indicates whether the remote sensor is currently
  ** in use by a comfort setting
  const Bool inUse

  ** The list of remote sensor capability objects for the remote sensor
  const EcobeeRemoteSensorCapability[] capability := [,]

//////////////////////////////////////////////////////////////////////////
// RemoteSensor
//////////////////////////////////////////////////////////////////////////

  ** Get the capability with the given type or return null
  ** if this sensor doesn't support this capability
  EcobeeRemoteSensorCapability? getCapability(Str type)
  {
    capability.find { it.type == type }
  }

  ** Return true if this sensor supports the capability with the given type
  Bool hasCapability(Str type) { getCapability(type) != null }

}