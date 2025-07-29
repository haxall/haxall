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
using xetom
using haystack
using obs
using folio
using hx

**
** ExtSpi implementation
**
const class HxExtSpi : Actor, ExtSpi
{

//////////////////////////////////////////////////////////////////////////
// Ext Factory
//////////////////////////////////////////////////////////////////////////

  ** Instantiate the Ext for given lib if available
  static ExtObj? instantiate(HxBoot? boot, HxProjExts exts, Lib lib)
  {
    // check for libExt meta
    ref := lib.meta["libExt"] as Ref
    if (ref == null) return null

    // try rest in try block...
    log  := exts.log
    name := lib.name
    try
    {
      // lookup the spec
      spec := exts.proj.ns.spec(ref.id, false)
      if (spec == null) { log.warn("Unknown lib ext spec: $ref"); return null }

      // verify type
      type := spec.fantomType
      if (type.name == "Dict") { log.warn("Missing fantom type binding: $spec"); return null }

      // determine constructor to use
      ctor := type.method("make")
      ctorNeedBoot := !ctor.params.isEmpty
      if (ctorNeedBoot && boot == null)  { log.warn("Ext type requires boot: $type"); return null }
      ctorArgs := ctorNeedBoot ? [boot] : null

      // read settings
      settings := exts.proj.settingsMgr.extRead(name)

      // create spi instance
      spi := HxExtSpi(exts.proj, name, spec, type, settings, exts.actorPool)

      // instantiate fantom type
      ExtObj? ext
      Actor.locals["hx.spi"] = spi
      try
      {
        ext = ctor.callList(ctorArgs)
      }
      finally
        Actor.locals.remove("hx.spi")

      // bind spi to ext instance
      spi.extRef.val = ext

      // done!
      return ext
    }
    catch (Err e)
    {
      log.err("Cannot init ext: $ref", e)
      return null
    }
  }

  private new make(HxProj proj, Str name, Spec spec, Type type, Dict settings, ActorPool pool) : super(pool)
  {
    this.projRef     = proj
    this.name        = name
    this.qname       = spec.qname
    this.log         = Log.get(name)
    this.fantomType  = type
    this.settingsRef = AtomicRef(typedRec(settings))
  }

//////////////////////////////////////////////////////////////////////////
// ExtSpi Implementation
//////////////////////////////////////////////////////////////////////////

  ExtObj ext() { extRef.val }
  private const AtomicRef extRef := AtomicRef()

  override Proj proj() { projRef }
  const HxProj projRef

  override const Str name

  const Str qname

  const Type fantomType

  override Spec spec() { proj.ns.spec(qname) }

  override Dict settings() { settingsRef.val }
  private const AtomicRef settingsRef

  override Void settingsUpdate(Obj changes)
  {
    projRef.settingsMgr.extUpdate(this, changes)
  }

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
// Observables
//////////////////////////////////////////////////////////////////////////

  override Subscription[] subscriptions() { subscriptionsRef.val }
  private const AtomicRef subscriptionsRef := AtomicRef(Subscription#.emptyList)

  override Subscription observe(Str name, Dict config, Obj callback)
  {
    observer := callback is Actor ? ExtActorObserver(ext, callback) : ExtMethodObserver(ext, callback)
    sub := proj.obs.get(name).subscribe(observer, config)
    subscriptionsRef.val = subscriptions.dup.add(sub).toImmutable
    return sub
  }

//////////////////////////////////////////////////////////////////////////
// Background Processing
//////////////////////////////////////////////////////////////////////////

  Future start() { send(HxMsg("start"))  }

  Future ready() { send(HxMsg("ready")) }

  Future steadyState() { send(HxMsg("steadyState")) }

  Future unready() { send(HxMsg("unready")) }

  Future stop() { send(HxMsg("stop")) }

  override Void sync(Duration? timeout := 30sec) { send((HxMsg("sync"))).get(timeout) }

  Future sysReload() { send(HxMsg("sysReload")) }

  Void update(Dict settings)
  {
    settingsRef.val = typedRec(settings)
    send(HxMsg("settings"))
  }

  Dict typedRec(Dict dict)
  {
    methodType := fantomType.method("settings").returns
    if (methodType.name == "Dict") return dict
    return Settings.create(methodType, dict) |warn| { log.warn(warn) }
  }

  override Obj? receive(Obj? msgObj)
  {
    if (msgObj === houseKeepingMsg)
    {
      if (!isRunning) return null
      try
        ext.onHouseKeeping
      catch (Err e)
        log.err("Ext.onHouseKeeping", e)
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
      if (msg.id === "sysReload")   return onSysReload
    }
    catch (Err e)
    {
      log.err("Ext callback", e)
      throw e
    }

    return ext.onReceive(msg)
  }

  private Obj? onStart()
  {
    isRunningRef.val = true
    try
    {
      ext.onStart
    }
    catch (Err e)
    {
      log.err("Ext.onStart", e)
      toStatus("fault", e.toStr)
    }
    return null
  }

  private Obj? onReady()
  {
    // kick off house keeping
    scheduleHouseKeeping

    // onReady callback
    ext.onReady

    return null
  }

  private Obj? onSteadyState()
  {
    ext.onSteadyState
    return null
  }

  private Obj? onUnready()
  {
    isRunningRef.val = false
    ext.onUnready
    return null
  }

  private Obj? onStop()
  {
    ext.onStop
    return null
  }

  private Obj? onSettings()
  {
    ext.onSettings
    return null
  }

  private Obj? onSysReload()
  {
    ext.onSysReload
    return null
  }

  private Obj? onObs(HxMsg msg)
  {
    ((ExtMethodObserver)msg.a).call(msg.b)
  }

  override Bool isRunning() { isRunningRef.val }
  private const AtomicBool isRunningRef := AtomicBool(false)

  private Void scheduleHouseKeeping()
  {
    freq := ext.houseKeepingFreq
    if (freq != null) sendLater(freq, houseKeepingMsg)
  }

  private static const HxMsg houseKeepingMsg := HxMsg("houseKeeping")
}

**************************************************************************
** ExtActorObserver
**************************************************************************

internal const class ExtActorObserver : Observer
{
  new make(Ext ext, Actor actor)
  {
    this.ext   = ext
    this.actor = actor
    this.meta  = Etc.dict0
  }

  const Ext ext
  override const Dict meta
  override const Actor actor
  override Str toStr() { "Ext $ext.name" }
}

**************************************************************************
** ExtMethodObserver
**************************************************************************

internal const class ExtMethodObserver : Observer
{
  new make(Ext ext, Method method)
  {
    this.ext    = ext
    this.actor  = (HxExtSpi)ext.spi
    this.method = method
    this.meta   = Etc.dict0
  }

  const Ext ext
  const Method method
  override const Dict meta
  override const Actor actor
  override Obj toActorMsg(Observation msg) { HxMsg("obs", this, msg) }
  override Obj? toSyncMsg() { HxMsg("sync") }
  override Str toStr() { "Ext $ext.name" }

  Obj? call(Obj? msg)
  {
    try
      method.callOn(ext, [msg])
    catch (Err e)
      ext.log.err("${ext.typeof}.observe", e)
    return null
  }
}

