//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   02 Feb 2022  Matthew Giannini  Creation
//

using oauth2

**
** Ecobee Thermostat Request API
**
class ThermostatReq : ApiReq
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  internal new make(Ecobee ecobee) : super(ecobee.client, ecobee.log)
  {
  }

//////////////////////////////////////////////////////////////////////////
// API
//////////////////////////////////////////////////////////////////////////

  ** This request retrieves a list of thermostat configuration and state revisions
  ThermostatSummaryResp summary(EcobeeSelection selection)
  {
    invokeGet(`thermostatSummary`, selection)
  }

  ** Get all thermostats matching the selection
  EcobeeThermostat[] get(EcobeeSelection selection)
  {
    acc  := EcobeeThermostat[,]
    page := 1
    while (true)
    {
      resp := invokeGet(`thermostat`, selection, page) as ThermostatResp
      acc.addAll(resp.thermostatList)

      // check for more pages
      if (!resp.morePages) break
      ++page
    }
    return acc
  }

  ** Write an update to the thermostat to change a setting or other value
  Void update(EcobeeSelection selection, EcobeeThermostat thermostat)
  {
    uri := baseUri.plus(`thermostat`).plusQuery(["format":"json"])
    bodyJson := [selection.jsonKey: selection, thermostat.jsonKey: thermostat]
    body := EcobeeEncoder.jsonStr(bodyJson).toBuf.toFile(`update.json`)
    resp := invoke("POST", uri, body)
  }

  ** Invoke an ecobee function
  Void callFunc(EcobeeSelection selection, EcobeeFunction func)
  {
    uri := baseUri.plus(`thermostat`).plusQuery(["format":"json"])
    bodyJson := [selection.jsonKey: selection, "functions": [func]]
    body := EcobeeEncoder.jsonStr(bodyJson).toBuf.toFile(`event.json`)
    resp := invoke("POST", uri, body)
  }
}

**************************************************************************
** ThermostatSummaryResp
**************************************************************************

**
** Contains the result of a thermostat summary request.
**
final const class ThermostatSummaryResp : EcobeeResp
{
  new make(|This| f) : super(f) { f(this) }

  ** Number of thermostats listed in the revision list
  const Int thermostatCount

  ** The list of CSV revision values
  const ThermostatRev[] revisionList

  ** The list of CSV status values
  const EquipmentStatus[] statusList

  ** Get the thermostat revisions mapped by thermostat identifier
  [Str:ThermostatRev] revisions()
  {
    [Str:ThermostatRev][:] { ordered = true }.setList(revisionList) { it.id }
  }
}

**************************************************************************
** ThermostatResp
**************************************************************************

final const class ThermostatResp : EcobeeResp
{
  new make(|This| f) : super(f) { f(this) }

  const EcobeeThermostat[] thermostatList
}

**************************************************************************
** ThermostatRev
**************************************************************************

final const class ThermostatRev
{
  ** Decode the thermostat revision from its CSV format
  static new fromStr(Str csv)
  {
    cols := csv.split(':')
    dec  := EcobeeDecoder()
    fields := Field:Obj[:]
    ThermostatRev#.fields.each |f, i|
    {
      fields[f] = dec.decode(cols[i], f.type)
    }
    setter := Field.makeSetFunc(fields)
    return ThermostatRev#.make([setter])
  }

  new make(|This| f) { f(this) }

  ** The thermostat identifier
  const Str id

  ** The thermostat name
  const Str name

  ** Is the thermostat currently connected to ecobee servers
  const Bool connected

  ** Current thermostat revision. The revision is incremented whenever
  ** the thermostat program, hvac mode, settings, or configuration change.
  ** Changes to the following objects will update the thermostat revision:
  ** - Settings
  ** - Program
  ** - Event
  ** - Device
  const Str thermostatRev

  ** Current revision of the thermostat alarms. This revision is incremented whenever
  ** a new Alert is issued or an Alert is modified (acknowledge or deferred).
  const Str alertsRev

  ** The current revision of the thermostat runtime settings. This revision is
  ** incremented whenever the thermostat transmits a new status message, or updates
  ** the equipment state, or Remote Sensor readings. The shortest interval
  ** this revision may change is 3 minutes.
  const Str runtimeRev

  ** The current revision of the thermostat interval runtime settings.
  ** This revision is incremented whenever the thermostat transmits a new
  ** status message in the form of a Runtime object. The thermostat updates
  ** this on a 15 minute interval.
  const Str intervalRev
}

**************************************************************************
** EquipmentStatus
**************************************************************************

final const class EquipmentStatus
{
  static new fromStr(Str csv)
  {
    cols := csv.split(':')
    dec  := EcobeeDecoder()
    fields := Field:Obj[:]
    EquipmentStatus#.fields.each |f, i|
    {
      fields[f] = dec.decode(cols[i], f.type)
    }
    setter := Field.makeSetFunc(fields)
    return EquipmentStatus#.make([setter])
  }

  new make(|This| f) { f(this) }

  ** The thermostat identifier
  const Str id

  ** The equipment status (if the equipment is currently running)
  const Str status
}