//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   03 Feb 2022  Matthew Giannini  Creation
//

**
** Thermostat object
**
const class EcobeeThermostat : EcobeeObj
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(|This| f) { f(this) }

  ** The unique thermostat serial number
  const Str identifier

  override Str? id() { identifier }

  ** A user defined name for the thermostat
  const Str? name

  ** The current thermostat configuration revision
  const Str? thermostatRev

  ** Whether the user registered the thermostat
  const Bool? isRegistered

  ** The thermostat model number
  const Str? modelNumber

  ** The thermostat brand
  const Str? brand

  ** The comma-separated list of the thermostat's additoinal features, if any
  const Str? features

  // TODO: lastModified, thermostatTime (these are stored in device time)
  // but without the timezone information. we'd need to provide utils
  // to turn these into DateTime from the location object

  const DateTime? utcTime

  // TODO: audio, alerts, reminders

  ** The thermostat settings object
  const EcobeeSettings? settings

  ** The runtime state object
  const EcobeeRuntime? runtime

  // TODO: extendedRuntime, devices, location, technician, utility, management, weather
  // events, program, houseDetails, oemCfg

  ** The status of all equipment controlled by this Thermostat.
  ** Only running equipment is listed in the CSV String.
  const Str? equipmentStatus

  // TODO: notificationSettings, privacy,

  ** The version object containing the firmware version for the thermostat
  const EcobeeVersion? version

  // TODO: securitySettings, filterSubscription

  ** The list of remote sensor objects for this thermostat
  const EcobeeRemoteSensor[] remoteSensors := [,]

  // TODO: capabilities

}

**************************************************************************
** EcobeeVersion
**************************************************************************

const class EcobeeVersion : EcobeeObj
{
  static new fromStr(Str val)
  {
    EcobeeVersion { it.thermostatFirmwareVersion = Version(val) }
  }

  new make(|This| f) { f(this) }

  const Version? thermostatFirmwareVersion

}