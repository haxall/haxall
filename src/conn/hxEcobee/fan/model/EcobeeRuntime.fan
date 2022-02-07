//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   03 Feb 2022  Matthew Giannini  Creation
//

**
** Runtime object
**
const class EcobeeRuntime : EcobeeObj
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(|This| f) { f(this) }

  ** The current runtime revision. Equivalent in meaning to the runtime
  ** revision number in the thermostat summary call.
  const Str? runtimeRev

  ** Whether the thermostat is currently connected to the server
  const Bool? connected

  ** The UTC dat/time stamp of when the thermostat first connected to the server
  const DateTime? firstConnected

  ** The last recorded connection date and time
  const Str? connectDateTime

  ** The last recorded disconnection date and time
  const Str? disconnectDateTime

  ** The UTC date/timestamp of when the thermostat was updated
  const DateTime? lastModified

  ** The UTC date/timestamp of when the thermostat last posted its
  ** runtime information
  const DateTime? lastStatusModified

  ** The UTC date of the last runtime reading
  const Date? runtimeDate

  ** The last 5 minute interval which was updated by the thermostat telemetry update.
  ** Subtract 2 from this interval to obtain the beginning interval for the
  ** last 3 readings. Multiply by 5 mins to obtain the minutes of the day. Range 0-287
  const Int? runtimeInterval

  ** The current temperature displayed on the thermostat
  const Int? actualTemperature

  ** The current humidity % shown on the thermostat
  const Int? actualHumidity

  ** The dry-bulb temperature recorded by the thermostat.
  const Int? rawTemperature

  // showIconMode

  ** The desired heat temperature as per the current running program or active event
  const Int? desiredHeat

  ** The desired cool temperature as per the current running program or active event
  const Int? desiredCool

  ** The desired humidity set point
  const Int? desiredHumidity

  ** The desired fan mode. Values: auto, on, or null if the HVAC system
  ** is off and the thermostat is not controlling a fan independently.
  const Str? desiredFanMode

  const Int? actualVOC

  const Int? actualCO2

  const Int? actualAQAccuracy

  const Int? actualAQScore

  ** This field provides the possible valid range for which a desiredHeat
  ** setpoint can be set to. This value takes into account the thermostat heat
  ** temperature limits as well the running program or active events. Values are
  ** returned as an Integer array representing the canonical minimum
  ** and maximum, e.g. [450,790].
  const Int[]? desiredHeatRange

  ** This field provides the possible valid range for which a desiredCool
  ** setpoint can be set to. This value takes into account the thermostat cool
  ** temperature limits as well the running program or active events. Values are
  ** returned as an Integer array representing the canonical minimum
  ** and maximum, e.g. [650,920].
  const Int[]? desiredCoolRange

}