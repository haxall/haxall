//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   02 Feb 2022  Matthew Giannini  Creation
//

**
** Selection object
**
const class EcobeeSelection : EcobeeObj
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(|This| f) { f(this) }

  ** The type of match data supplied
  const SelectionType selectionType

  ** The match data based on selection type (e.g. a list of thermostat identifiers)
  const Str selectionMatch := ""

  ** Include the thermostat runtime object
  const Bool includeRuntime := false

  ** Include the extended thermostat runtime object
  const Bool includeExtendedRuntime := false

  ** Include the thermostat settings object
  const Bool includeSettings := false

  ** Include the thermostat location object
  const Bool includeLocation := false

  ** Include the thermostat program object
  const Bool includeProgram := false

  ** Include the thermostat calendar events objects
  const Bool includeEvents := false

  ** Include the thermostat device configuration objects
  const Bool includeDevice := false

  ** Include the thermostat technician object
  const Bool includeTechnician := false

  ** Include the thermostat utility company object
  const Bool includeUtility := false

  ** Include the thermostat management company object
  const Bool includeManagement := false

  ** Include the thermostat's unacknowledged alert objects
  const Bool includeAlerts := false

  //const Bool includeReminders := false

  ** Include the current thermostat weather forecast object
  const Bool includeWeather := false

  ** Include the current thermostat house details object
  const Bool includeHouseDetails := false

  ** Include the current thermostat OemCfg object
  const Bool includeOemCfg := false

  ** Include the current thermostat equipment status information
  const Bool includeEquipmentStatus := false

  ** Include the current thermostat equipment status information
  const Bool includeNotificationSettings := false

  ** Include the current thermostat privacy settings
  const Bool includePrivacy := false

  ** Include the current firmware version the Thermostat is running
  const Bool includeVersion := false

  ** Include the current security settings object for the selected thermostat(s)
  const Bool includeSecurity := false

  ** Include the list of current thermostat remote sensor objects for the selected thermostat(s)
  const Bool includeSensors := false

  ** Include the audio configuration for the selected thermostat(s)
  const Bool includeAudid := false

  ** Include the energy configuration for the selected thermostat(s)
  const Bool includeEnergy := false

  const Bool includeCapabilities := false
}

**************************************************************************
** SelectionType
**************************************************************************

** Ecobee selection type enum
enum class SelectionType { registered, thermostats, managementSet }