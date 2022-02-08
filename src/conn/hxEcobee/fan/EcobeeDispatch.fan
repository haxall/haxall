//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   02 Feb 2022  Matthew Giannini  Creation
//

using haystack
using hx
using hxConn

class EcobeeDispatch : ConnDispatch
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(Obj arg) : super(arg) {}

  private EcobeeLib ecobeeLib() { lib }

  internal Ecobee? client

  private ThermostatSummaryResp? latestSummary

  private DateTime lastPollSummary := DateTime.defVal

//////////////////////////////////////////////////////////////////////////
//  Open/Ping/Close
//////////////////////////////////////////////////////////////////////////

  override Void onOpen()
  {
    this.client = Ecobee(password("ecobeeClientId"), password("ecobeeRefreshToken"), trace.asLog)
    pollSummary
  }

  private Str password(Str name)
  {
    db.passwords.get("$id $name") ?: throw FaultErr("Missing password for $name")
  }

  override Void onClose()
  {
    this.client = null
  }

  override Dict onPing()
  {
    return Etc.emptyDict()
  }

//////////////////////////////////////////////////////////////////////////
//  Ecobee
//////////////////////////////////////////////////////////////////////////

  private static const Duration ecobeePollInterval := 3min

  internal ThermostatSummaryResp pollSummary()
  {
    // only poll summary after poll interval time has elapsed
    if (lastPollSummary + ecobeePollInterval < DateTime.now)
    {
      this.latestSummary = client.thermostat.summary(EcobeeSelection {
        it.selectionType = SelectionType.registered
        it.includeRuntime = true
      })

      this.lastPollSummary = DateTime.now
    }

    return latestSummary
  }

//////////////////////////////////////////////////////////////////////////
// Points
//////////////////////////////////////////////////////////////////////////

  override Void onSyncCur(ConnPoint[] points)
  {
    EcobeeSyncCur(this, points).run
  }

  override Void onWrite(ConnPoint point, ConnWriteInfo event)
  {
    EcobeeWrite(this, point, event).run
  }

//////////////////////////////////////////////////////////////////////////
// Learn
//////////////////////////////////////////////////////////////////////////

  override Grid onLearn(Obj? arg)
  {
    EcobeeLearn(this, arg).learn
  }
}

