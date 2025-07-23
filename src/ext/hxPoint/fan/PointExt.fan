//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Jul 2012  Brian Frank  Creation
//   14 Jul 2021  Brian Frank  Refactor for Haxall
//

using concurrent
using xeto
using haystack
using obs
using folio
using hx

**
** Point historization and writable support
**
const class PointExt : ExtObj, IPointExt
{
  new make()
  {
    enums         = EnumDefs()
    hisCollectMgr = HisCollectMgrActor(this)
    writeMgr      = WriteMgrActor(this)
    demoMgr       = DemoMgrActor(this)
    observables   = [writeMgr.observable]
  }

  override Grid pointArray(Dict point) { writeMgr.array(point) }

  override Future pointWrite(Dict point, Obj? val, Int level, Obj who, Dict? opts := null) { writeMgr.write(point, val, level, who, opts) }

  ** Return list of observables this library publishes
  override const Observable[] observables

  ** Should we collect bad data as NA or just omit it
  Bool hisCollectNA() { settings.has("hisCollectNA") }

  ** Start callback
  override Void onStart()
  {
    // subscribe to point commits (do this before we start
    // the managers so that all the init observations are received
    // before the first onCheck)
    observe("obsCommits",
      Etc.makeDict([
        "obsAdds":      Marker.val,
        "obsUpdates":   Marker.val,
        "obsRemoves":   Marker.val,
        "obsAddOnInit": Marker.val,
        "syncable":     Marker.val,
        "obsFilter":   "point"
      ]), #onPointEvent)

    // subscribe to enumMeta commits
    observe("obsCommits",
      Etc.makeDict([
        "obsAdds":      Marker.val,
        "obsUpdates":   Marker.val,
        "obsRemoves":   Marker.val,
        "obsAddOnInit": Marker.val,
        "syncable":     Marker.val,
        "obsFilter":   "enumMeta"
      ]), #onEnumMetaEvent)

    // start up manager checks
    if (settings.missing("disableWritables"))  writeMgr.start
    if (settings.missing("disableHisCollect")) hisCollectMgr.start
    if (settings.has("demoMode")) demoMgr.start
  }

  ** Stop callback
  override Void onStop()
  {
    writeMgr.stop
    hisCollectMgr.stop
    demoMgr.stop
  }

  ** Steady state callback
  override Void onSteadyState()
  {
    if (writeMgr.isRunning) writeMgr.forceCheck
  }

  ** Event when 'enumMeta' record is modified
  internal Void onEnumMetaEvent(CommitObservation? e)
  {
    // null is sync message
    if (e == null) return

    newRec := e.newRec
    if (newRec.has("trash")) newRec = Etc.dict0
    enums.updateMeta(newRec, log)
  }

  ** Event when 'point' record is modified
  internal Void onPointEvent(CommitObservation? e)
  {
    // null is sync message
    if (e == null)
    {
      writeMgr.sync
      hisCollectMgr.sync
      return
    }

    // check for writable changes
    if (e.recHas("writable"))
      writeMgr.send(HxMsg("obs", e))

    // check for hisCollect changes
    if (PointUtil.isHisCollect(e.oldRec) || PointUtil.isHisCollect(e.newRec))
      hisCollectMgr.send(HxMsg("obs", e))
  }

  internal const EnumDefs enums
  internal const HisCollectMgrActor hisCollectMgr
  internal const WriteMgrActor writeMgr
  internal const DemoMgrActor demoMgr
}

