//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Jul 2012  Brian Frank  Creation
//   14 Jul 2021  Brian Frank  Refactor for Haxall
//

using concurrent
using haystack
using obs
using folio
using hx

**
** Point historization and writable support
**
const class PointLib : HxLib
{
  new make()
  {
    enums         = EnumDefs()
    hisCollectMgr = HisCollectMgrActor(this)
    writeMgr      = WriteMgrActor(this)
    demoMgr       = DemoMgrActor(this)
    observables   = [writeMgr.observable]
  }

  ** Return list of observables this library publishes
  override const Observable[] observables

  ** Should we collect bad data as NA or just omit it
  Bool hisCollectNA() { rec.has("hisCollectNA") }

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
    if (rec.missing("disableWritables"))  writeMgr.start
    if (rec.missing("disableHisCollect")) hisCollectMgr.start
    if (rec.has("demoMode")) demoMgr.start
  }

  ** Event when 'enumMeta' record is modified
  internal Void onEnumMetaEvent(CommitObservation? e)
  {
    // null is sync message
    if (e == null) return

    newRec := e.newRec
    if (newRec.has("trash")) newRec = Etc.emptyDict
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


