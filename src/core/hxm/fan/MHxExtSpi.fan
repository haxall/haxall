//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//    8 Jul 2025  Brian Frank  Redesign from HxdLibSpi
//

using concurrent
using xeto
using haystack
using obs
using folio
using hx

**
** HxExtSpi implementation
**
const class MHxExtSpi : Actor, HxExtSpi
{

//////////////////////////////////////////////////////////////////////////
// Factory
//////////////////////////////////////////////////////////////////////////

  ** Instantiate the HxExt
  static HxExt instantiate(MHxProj proj, Lib lib, Dict settings)
  {
    spi := MHxExtSpi(proj, lib, settings)
    Actor.locals["hx.spi"]  = spi
    try
    {
      ext := doInstantiate(spi)
      spi.extRef.val = ext
      return ext
    }
    finally
    {
      Actor.locals.remove("hx.spi")
    }
  }

  private static HxExt doInstantiate(MHxExtSpi spi)
  {
    spi.type.make
  }

  private new make(MHxProj proj, Lib lib, Dict settings) : super(proj.extActorPool)
  {
    this.proj        = proj
    this.name        = lib.name
    this.type        = Type.find("TODO")
    this.log         = Log.get(name)
    this.settingsRef = AtomicRef(typedRec(settings))
  }

//////////////////////////////////////////////////////////////////////////
// HxExtSpi Implementation
//////////////////////////////////////////////////////////////////////////

  HxExt lib() { extRef.val }
  private const AtomicRef extRef := AtomicRef()

  override const HxProj proj

  override const Str name

  const Type type

  override Dict settings() { settingsRef.val }
  private const AtomicRef settingsRef

  override const Log log

  override Actor actor() { this }

  override Bool isFault() { status == "fault" }

  override Void toStatus(Str status, Str msg)
  {
    if (status != "fault") throw ArgErr("unsupported status")
    statusRef.val = "fault"
    statusMsgRef.val = msg
  }

  Str status() { statusRef.val }

  Str? statusMsg() { statusMsgRef.val }

  private const AtomicRef statusRef := AtomicRef("ok")
  private const AtomicRef statusMsgRef := AtomicRef(null)

//////////////////////////////////////////////////////////////////////////
// Background Processing
//////////////////////////////////////////////////////////////////////////

  override Void sync(Duration? timeout := 30sec)
  {
    send((HxMsg("sync"))).get(timeout)
  }

  Future start() { send(HxMsg("start"))  }

  Future ready() { send(HxMsg("ready")) }

  Future steadyState() { send(HxMsg("steadyState")) }

  Future unready() { send(HxMsg("unready")) }

  Future stop() { send(HxMsg("stop")) }

  Void update(Dict settings)
  {
    settingsRef.val = typedRec(settings)
    send(HxMsg("settings", null))
  }

  Dict typedRec(Dict dict)
  {
    recType := type.method("settings").returns
    if (recType.name == "Dict") return dict
    return TypedDict.create(recType, dict) |warn| { log.warn(warn) }
  }

  override Obj? receive(Obj? msgObj)
  {
    if (msgObj === houseKeepingMsg)
    {
      if (!isRunning) return null
      try
        lib.onHouseKeeping
      catch (Err e)
        log.err("HxExt.onHouseKeeping", e)
      scheduleHouseKeeping
      return null
    }

    msg := msgObj as HxMsg ?: throw ArgErr("Invalid msg type: ${msgObj?.typeof}")
    try
    {
      if (msg.id === "obs")         return onObs(msg)
      if (msg.id === "sync")        return "synced"
      if (msg.id === "settings")    return onSettings
      if (msg.id === "start")       return onStart
      if (msg.id === "ready")       return onReady
      if (msg.id === "steadyState") return onSteadyState
      if (msg.id === "unready")     return onUnready
      if (msg.id === "stop")        return onStop
    }
    catch (Err e)
    {
      log.err("HxExt callback", e)
      throw e
    }

    return lib.onReceive(msg)
  }

  private Obj? onStart()
  {
    isRunningRef.val = true
    try
    {
      lib.onStart
    }
    catch (Err e)
    {
      log.err("HxExt.onStart", e)
      toStatus("fault", e.toStr)
    }
    return null
  }

  private Obj? onReady()
  {
    // kick off house keeping
    scheduleHouseKeeping

    // onReady callback
    lib.onReady

    return null
  }

  private Obj? onSteadyState()
  {
    lib.onSteadyState
    return null
  }

  private Obj? onUnready()
  {
    isRunningRef.val = false
    lib.onUnready
    return null
  }

  private Obj? onStop()
  {
    lib.onStop
    return null
  }

  private Obj? onSettings()
  {
    lib.onSettings
    return null
  }

  private Obj? onObs(HxMsg msg)
  {
throw Err("TODO")
//    ((HxdLibMethodObserver)msg.a).call(msg.b)
  }

  override Bool isRunning() { isRunningRef.val }
  private const AtomicBool isRunningRef := AtomicBool(false)

  private Void scheduleHouseKeeping()
  {
    freq := lib.houseKeepingFreq
    if (freq != null) sendLater(freq, houseKeepingMsg)
  }

  private static const HxMsg houseKeepingMsg := HxMsg("houseKeeping")
}

**************************************************************************
** ResHxLib
**************************************************************************

** ResHxLib is a stub for libraries without a Fantom class
const class ResHxLib : HxLib
{
}

