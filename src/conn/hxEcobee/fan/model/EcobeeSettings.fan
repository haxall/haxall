//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   07 Feb 2022  Matthew Giannini  Creation
//

**
** Settings object
**
const class EcobeeSettings : EcobeeObj
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(|This| f) { f(this) }

  ** The current HVAC mode the thermostat is in. Values:
  ** auto, auxHeatOnly, cool, heat, off
  const Str? hvacMode

  ** The last service data of the HVAC equipment
  const Date? lastServiceDate

  ** Whether to send an alert when service is required again.
  const Bool? serviceRemindMe

  ** The user configured monthly interval between HVAC service reminders
  const Int? monthsBetweenService

  ** Date to be reminded about the next HVAC service date
  const Date? remindMeDate

  ** The ventilator mode. Value: auto, minontime, on, off
  const Str? vent

  ** The minimu time in minutes the ventilator is configured to run.
  ** The thermostat will always guarantee that the ventilator runs for this
  ** minimum duration whenever engaged.
  const Int? ventilatorMinOnTime

  ** Whether the technician associated with this thermostat should receive
  ** the HVAC service reminders as well.
  const Bool? serviceRemindTechnician

  ** A note about the physical location where the SMART or EMS
  ** Equipment Interface module is located
  const Str? eiLocation

  ** The temperature at which a cold temp alert is triggered
  const Int? coldTempAlert

  ** Whether cold temperature alerts are enabled
  const Bool? coldTempAlertEnabled

  ** The temperature at which a hot temp alert is triggered
  const Int? hotTempAlert

  ** Whether hot temperature alerts are enabled
  const Bool? hotTempAlertEnabled

  ** The number of cool stage the connected HVAC equipment supports
  const Int? coolStages

  ** The number of heat stages the connected HVAC equipment supports
  const Int? heatStages

  ** The maximum automated set point set back offset allowed in degress
  const Int? maxSetBack

  ** The maximum automated set point set forward offset allowed in degrees
  const Int? maxSetForward

  ** The set point set back offset, in degrees, configured for a quick save event
  const Int? quickSaveSetBack

  ** The set point set forward offset, in degrees, configured for a quick save event
  const Int? quickSaveSetForward

  ** Whether the thermostat is controlling a heat pump
  const Bool? hasHeatPump

  ** Whether the thermostat is controlling a forced air furnace
  const Bool? hasForcedAir

  ** Whether the thermostat is controlling a boiler
  const Bool? hasBoiler

  ** Whether the thermostat is controlling a humidifier
  const Bool? hasHumidifier

  ** Whether the thermostat is controlling an energy recovery ventilator
  const Bool? hasErv

  ** Whether the thermostat is controlling a heat recovery ventilator
  const Bool? hasHrv

  ** Whether the thermostat is in frost control mode
  const Bool? condensationAvoid

  ** Whether the thermostat is configured to report in degrees Celsisus
  const Bool? useCelsius

  ** Whether the thermostat is using 12hr time format
  const Bool? userTimeFormat12

  ** Multilanguage support
  const Str? locale

  ** The minimum humidity level (in percent) set point for the humidifier
  const Str? humidity

  ** The humidifier mode. Values: auto, manual, off
  const Str? humidifierMode

  ** The thermostat backlight intensity when on. A value between
  ** 0 and 10, with 0 meaning 'off' - the zero value may not be honored by
  ** all ecobee versions
  const Int? backlightOnIntensity

  ** The thermostat backlight intensity when asleep. A value between
  ** 0 and 10, with 0 meaning 'off' - the zero value may not be honored
  ** by all ecobee versions
  const Int? backlightSleepIntensity

  ** The time in seconds before the thermostat screen goes into sleep mode
  const Int? backlightOffTime

  ** The minimum time the compressor must be off for in order to prevent short-cycling
  const Int? compressorProtectionMinTime

  ** The minimum outdoor temperature that the compressor can operate at
  ** - applies more to air source heat pumps than geothermal
  const Int? compressorProtectionMinTemp

  ** The difference between current temp and set-point that will trigger stage 2 heating
  const Int? stage1HeatingDifferentialTemp

  ** The difference between current temperature and set-point that will trigger stage 2 cooling.
  const Int? stage1CoolingDifferentialTemp

  ** The time after a heating cycle that the fan will run for to extract any
  ** heating left in the system - 30 second default.
  const Int? stage1HeatingDissipationTime

  ** The time after a cooling cycle that the fan will run for to extract any cooling
  ** left in the system - 30 second default (for not)
  const Int? stage1CoolingDissipationTime

  ** The flag to tell if the heat pump is in heating mode or in cooling when the
  ** relay is engaged. If set to zero it's heating when the reversing valve
  ** is open, cooling when closed and if it's one - it's the opposite.
  const Bool? heatPumpReversalOnCool

  ** Whether fan control by the Thermostat is required in auxiliary heating
  ** (gas/electric/boiler), otherwise controlled by furnace.
  const Bool? fanControlRequired

  ** The minimum time, in minutes, to run the fan each hour. Value from 1 to 60.
  const Int? fanMinOnTime

  ** The minimum temperature difference between the heat and cool values.
  ** Used to ensure that when thermostat is in auto mode, the heat and cool values
  ** are separated by at least this value.
  const Int? heatCoolMinDelta

  ** The amount to adjust the temperature reading in degrees F - this value is
  ** subtracted from the temperature read from the sensor.
  const Int? tempCorrection

  ** The default end time setting the thermostat applies to user temperature holds.
  ** Values useEndTime4hour, useEndTime2hour (EMS Only), nextPeriod, indefinite, askMe
  const Str? holdAction

  ** Whether the Thermostat uses a geothermal / ground source heat pump.
  const Bool? heatPumpGroundWater

  ** Whether the thermostat is connected to an electric HVAC system.
  const Bool? hasElectric

  ** Whether the thermostat is connected to a dehumidifier.
  ** If true or dehumidifyOvercoolOffset > 0 then allow setting dehumidifierMode
  ** and dehumidifierLevel.
  const Bool? hasDehumidifier

  ** The dehumidifier mode. Values: on, off.
  ** If set to off then the dehumidifier will not run, nor will the AC overcool run.
  const Str? dehumidifierMode

  ** The dehumidification set point in percentage.
  const Int? dehumidifierLevel

  **  Whether the thermostat should use AC overcool to dehumidify.
  ** When set to true a positive integer value must be supplied for
  ** dehumidifyOvercoolOffset otherwise an API validation exception will be thrown.
  const Bool? dehumidifyWithAC

  ** Whether the thermostat should use AC overcool to dehumidify and what that
  ** temperature offset should be. A value of 0 means this feature is disabled
  ** and dehumidifyWithAC will be set to false. Value represents the value in F to
  ** subtract from the current set point. Values should be in the
  ** range 0 - 50 and be divisible by 5.
  const Int? dehumidifyOvercoolOffset

  ** If enabled, allows the Thermostat to be put in HVACAuto mode.
  const Bool? autoHeatCoolFeatureEnabled

  ** Whether the alert for when wifi is offline is enabled.
  const Bool? wifiOfflineAlert

  ** The minimum heat set point allowed by the thermostat firmware.
  const Int? heatMinTemp

  ** The maximum heat set point allowed by the thermostat firmware.
  const Int? heatMaxTemp

  ** The minimum cool set point allowed by the thermostat firmware.
  const Int? coolMinTemp

  ** The maximum cool set point allowed by the thermostat firmware.
  const Int? coolMaxTemp

  ** The maximum heat set point configured by the user's preferences.
  const Int? heatRangeHigh

  ** The minimum heat set point configured by the user's preferences.
  const Int? heatRangeLow

  ** The maximum cool set point configured by the user's preferences.
  const Int? coolRangeHigh

  ** The minimum heat set point configured by the user's preferences.
  const Int? coolRangeLow

  ** The user access code value for this thermostat.
  ** See the SecuritySettings object for more information.
  const Str? userAccessCode

  ** The integer representation of the user access settings.
  ** See the SecuritySettings object for more information.
  const Int? userAccessSetting

  ** The temperature at which an auxHeat temperature alert is triggered.
  const Int? auxRuntimeAlert

  ** The temperature at which an auxOutdoor temperature alert is triggered.
  const Int? auxOutdoorTempAlert

  ** The maximum outdoor temperature above which aux heat will not run.
  const Int? auxMaxOutdoorTemp

  ** Whether the auxHeat temperature alerts are enabled.
  const Bool? auxRuntimeAlertNotify

  ** Whether the auxOutdoor temperature alerts are enabled.
  const Bool? auxOutdoorTempAlertyNotify

  ** Whether the auxHeat temperature alerts for the technician are enabled.
  const Bool? auxRuntimeAlertNotifyTechnician

  ** Whether the auxOutdoor temperature alerts for the technician are enabled.
  const Bool? auxOutdoorTempAlertNotifyTechnician

  ** Whether the thermostat should use pre heating to reach the set point on time.
  const Bool? disablePreHeating

  ** Whether the thermostat should use pre cooling to reach the set point on time.
  const Bool? disablePreCooling

  ** Whether an installer code is required
  const Bool? installerCodeRequired

  **  Whether Demand Response requests are accepted by this thermostat.
  ** Possible values are: always, askMe, customerSelect, defaultAccept, defaultDecline, never.
  const Str? drAccept

  ** Whether the property is a rental, or not
  const Bool? isRentalProperty

  ** Whether to use a zone controller or not
  const Bool? useZoneController

  ** Whether random start delay is enabled for cooling.
  const Int? randomStartDelayCool

  ** Whether random start delay is enabled for heating
  const Int? randomStartDelayHeat

  ** The humidity level to trigger a high humidity alert.
  const Int? humidityHighAlert

  ** The humidity level to trigger a low humidity alert.
  const Int? humidityLowAlert

  ** Whether heat pump alerts are disabled.
  const Bool? disableHeatPumpAlerts

  ** Whether alerts are disabled from showing on the thermostat.
  const Bool? disableAlertsOnIdt

  ** Whether humidification alerts are enabled to the thermostat owner.
  const Bool? humidityAlertNotify

  ** Whether humidification alerts are enabled to the technician associated with the thermostat.
  const Bool? humidityAlertNotifyTechnician

  ** Whether temperature alerts are enabled to the thermostat owner
  const Bool? tempAlertNotify

  ** Whether temperature alerts are enabled to the technician associated with the thermostat.
  const Bool? tempAlertNotifyTechnician

  ** The dollar amount the owner specifies for their desired maximum electricity bill.
  const Int? monthlyElectricityBillLimit

  ** Whether electricity bill alerts are enabled.
  const Bool? enableElectricityBillAlert

  ** Whether electricity bill projection alerts are enabled
  const Bool? enableProjectedElectricityBillAlert

  ** The day of the month the owner's electricity usage is billed.
  const Int? electricityBillingDayOfMonth

  ** The owners billing cycle duration in months.
  const Int? electricityBillCycleMonths

  ** The annual start month of the owners billing cycle.
  const Int? electricityBillStartMonth

  ** The number of minutes to run ventilator per hour when home.
  const Int? ventilatorMinOnTimeHome

  ** The number of minutes to run ventilator per hour when away.
  const Int? ventilatorMinOnTimeAway

  ** Determines whether or not to turn the backlight off during sleep.
  const Bool? backlightOffDuringSleep

  ** When set to true if no occupancy motion detected thermostat will go
  ** into indefinite away hold, until either the user presses resume
  ** schedule or motion is detected.
  const Bool? autoAway

  ** When set to true if a larger than normal delta is found between
  ** sensors the fan will be engaged for 15min/hour.
  const Bool? smartCirculation

  ** When set to true if a sensor has detected presence for more than
  ** 10 minutes then include that sensor in temp average. If no activity has
  ** been seen on a sensor for more than 1 hour then remove this sensor from temperature average.
  const Bool? followMeComfort

  ** This read-only field represents the type of ventilator present for the Thermostat.
  ** The possible values are none, ventilator, hrv, and erv.
  const Str? ventilatorType

  ** This Boolean field represents whether the ventilator timer is on or off.
  ** The default value is false. If set to true the ventilatorOffDateTime is
  ** set to now() + 20 minutes. If set to false the ventilatorOffDateTime is
  ** set to it's default value.
  const Bool? isVentilatorTimerOn

  ** This read-only field represents the Date and Time the ventilator will run until.
  ** The default value is 2014-01-01 00:00:00.
  const Str? ventilatorOffDateTime

  ** This Boolean field represents whether the HVAC system has a UV filter.
  ** The default value is true.
  const Bool? hasUVFilter

  ** This field represents whether to permit the cooling to operate when the Outdoor
  ** temperature is under a specific threshold, currently 55F. The default value is false.
  const Bool? coolingLockout

  **  Whether to use the ventilator to dehumidify when climate or calendar event
  ** indicates the owner is home. The default value is false.
  const Bool? ventilatorFreeCooling

  ** This field represents whether to permit dehumidifier to operate when the heating is running.
  ** The default value is false.
  const Bool? dehumidfyWhenHeating

  ** This field represents whether or not to allow dehumidification when cooling.
  ** The default value is true.
  const Bool? ventilatorDehumidify

  ** The unique reference to the group this thermostat belongs to, if any.
  ** See GET Group request and POST Group request for more information.
  const Str? groupRef

  ** The name of the the group this thermostat belongs to, if any.
  ** See GET Group request and POST Group request for more information.
  const Str? groupName

  ** The setting value for the group this thermostat belongs to, if any.
  ** See GET Group request and POST Group request for more information.
  const Int? groupSetting

  ** What's the default Fan Speed on a HVAC with multi-span.
  ** Accepted values: low, medium, high, and optimized.
  const Str? fanSpeed

}