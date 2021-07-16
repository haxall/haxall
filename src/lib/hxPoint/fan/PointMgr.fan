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
** Base class for the point managers:
**   - WriteMgr
**   - HisCollectMgr
**   - DemoMgr
**
internal abstract class PointMgr
{
  new make(PointLib lib)
  {
    this.lib = lib
    this.rt  = lib.rt
    this.log = lib.log
  }

  const PointLib lib
  const HxRuntime rt
  const Log log

  abstract Void onCheck()

  abstract Str? onDetails(Ref id)

  abstract Obj? onObs(CommitObservation e)

  virtual Obj? onReceive(HxMsg msg)
  {
    if (msg.id === "obs")     return onObs(msg.a)
    if (msg.id === "details") return onDetails(msg.a)
    if (msg.id === "sync")    return null
    throw Err("Unknown msg: $msg.id")
  }
}

**************************************************************************
** PointMgrActor
**************************************************************************

**
** PointMgrActor wraps a PointMgr
**
internal const class PointMgrActor : Actor
{
  new make(PointLib lib, Duration checkFreq, Type mgrType) : super(lib.rt.libs.actorPool)
  {
    this.lib       = lib
    this.checkFreq = checkFreq
    this.mgrType   = mgrType
    this.log       = lib.log
  }

  const PointLib lib
  const Duration checkFreq
  const Type mgrType
  const Log log

  Void obs(CommitObservation e) { send(HxMsg("obs", e)) } // async

  Str? details(Ref id) { send(HxMsg("details", id)).get(timeout) }

  Void sync(Duration? timeout := 30sec) { send(HxMsg("sync")).get(timeout) }

  Void onStart() { send(startMsg) }

  override Obj? receive(Obj? msg)
  {
    //  fault
    if (lib.spi.isFault) return null

    // house keeping
    if (msg === checkMsg)
    {
      try
      {
        PointMgr manager := Actor.locals["pm"]
        manager.onCheck
      }
      catch (ShutdownErr e) {}
      catch (Err e) log.err("onCheck", e)
      sendLater(checkFreq, checkMsg)
      return null
    }

    // start
    if (msg === startMsg)
    {
      try
      {
        PointMgr mgr := this.mgrType.make([lib])
        Actor.locals["pm"] = mgr
        sendLater(checkFreq, checkMsg)
      }
      catch (ShutdownErr e) {}
      catch (Err e) log.err("onStart", e)
      return null
    }

    // normal routing
    mgr := Actor.locals["pm"] as PointMgr
    if (mgr == null) throw DisabledErr("$this.mgrType.name disabled: $msg")
    return mgr.onReceive(msg)
  }

  private const static HxMsg startMsg := HxMsg("start")
  private const static HxMsg checkMsg := HxMsg("check")
  internal const static Duration timeout := 30sec
}

