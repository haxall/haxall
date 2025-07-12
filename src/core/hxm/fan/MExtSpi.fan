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
const class MExtSpi : Actor, ExtSpi
{

//////////////////////////////////////////////////////////////////////////
// Ext Factory
//////////////////////////////////////////////////////////////////////////

  ** Instantiate the Ext for given lib if available
  static Ext? instantiate(MProjExts exts, Lib lib)
  {
    // check for libExt meta
    ref := lib.meta["libExt"] as Ref
    if (ref == null) return null

    // try rest in try block...
    log  := exts.log
    try
    {
      // lookup the spec
      spec := exts.proj.ns.spec(ref.id, false)
      if (spec == null) { log.warn("Unknown lib ext spec: $ref"); return null }

      // verify type
      type := spec.fantomType
      if (type.name == "Dict") { log.warn("Missing fantom type binding: $spec"); return null }

      // read settings
      settings := Etc.dict0

      // create spi instance
      spi := MExtSpi(exts.proj, spec, type, settings, exts.actorPool)

      // instantiate fantom type
      Ext? ext
      Actor.locals["hx.spi"] = spi
      try
        ext = spi.fantomType.make
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

  private new make(HxRuntime proj, Spec spec, Type type, Dict settings, ActorPool pool) : super(pool)
  {
// TODO
name = type.pod.name
if (name.startsWith("hx") && !(name == "hxApi" || name == "hxUser"))
  name = name[2..-1].decapitalize

    this.rt          = proj
    this.qname       = spec.qname
    this.log         = Log.get(name)
    this.fantomType  = type
    this.settingsRef = AtomicRef(typedRec(settings))
    this.webUri      = ("/" + (name.startsWith("hx") ? name[2..-1].decapitalize : name) + "/").toUri

  }

//////////////////////////////////////////////////////////////////////////
// ExtSpi Implementation
//////////////////////////////////////////////////////////////////////////

// TODO
override const Str name
override DefLib def() { rt.defs.lib(name) }

  Ext ext() { extRef.val }
  private const AtomicRef extRef := AtomicRef()

  override const HxRuntime rt

  override const Str qname

  const Type fantomType

  override Spec spec() { rt.ns.spec(qname) }

  override Dict rec() { settingsRef.val }
  private const AtomicRef settingsRef

  override const Log log

  override const Uri webUri

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
    sub := rt.obs.get(name).subscribe(observer, config)
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

  Void update(Dict settings)
  {
    settingsRef.val = typedRec(settings)
    send(HxMsg("recUpdate", null))
  }

  Dict typedRec(Dict dict)
  {
    recType := fantomType.method("rec").returns
    if (recType.name == "Dict") return dict
    return TypedDict.create(recType, dict) |warn| { log.warn(warn) }
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
      if (msg.id === "recUpdate")   return onRecUpdate
      if (msg.id === "start")       return onStart
      if (msg.id === "ready")       return onReady
      if (msg.id === "steadyState") return onSteadyState
      if (msg.id === "unready")     return onUnready
      if (msg.id === "stop")        return onStop
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

  private Obj? onRecUpdate()
  {
    ext.onRecUpdate
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
    this.meta  = Etc.emptyDict
  }

  const Ext ext
  override const Dict meta
  override const Actor actor
  override Str toStr() { "Ext $ext.qname" }
}

**************************************************************************
** ExtMethodObserver
**************************************************************************

internal const class ExtMethodObserver : Observer
{
  new make(Ext ext, Method method)
  {
    this.ext    = ext
    this.actor  = (MExtSpi)ext.spi
    this.method = method
    this.meta   = Etc.emptyDict
  }

  const Ext ext
  const Method method
  override const Dict meta
  override const Actor actor
  override Obj toActorMsg(Observation msg) { HxMsg("obs", this, msg) }
  override Obj? toSyncMsg() { HxMsg("sync") }
  override Str toStr() { "Ext $ext.qname" }

  Obj? call(Obj? msg)
  {
    try
      method.callOn(ext, [msg])
    catch (Err e)
      ext.log.err("${ext.typeof}.observe", e)
    return null
  }
}

