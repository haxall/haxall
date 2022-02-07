//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   04 Feb 2022  Matthew Giannini  Creation
//

**
** RemoteSensorCapability object
**
const class EcobeeRemoteSensorCapability : EcobeeObj
{
  new make(|This| f) { f(this) }

  ** The unique sensor capability identifer
  **
  ** Note: the sensor id has no relation to its type
  override const Str? id

  ** The type of sensor capability.
  const Str? type

  ** The data value for this capability, always a string.
  const Str? value

}