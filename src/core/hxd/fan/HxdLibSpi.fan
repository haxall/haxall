//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using concurrent
using haystack
using obs
using folio
using hx

**
** Haxall daemon HxLib service provider implementation
**
const class HxdLibSpi : Actor, HxLibSpi
{

//////////////////////////////////////////////////////////////////////////
// HxLib Factory
//////////////////////////////////////////////////////////////////////////

  ** Instantiate the HxLib for given def and database rec
  static HxLib instantiate(HxdRuntime rt, HxdInstalledLib install, Dict rec)
  {
    spi := HxdLibSpi(rt, install, rec)
    Actor.locals["hx.spi"]  = spi
    try
    {
      lib := doInstantiate(spi)
      spi.libRef.val = lib
      return lib
    }
    finally
    {
      Actor.locals.remove("hx.spi")
    }
  }

  private static HxLib doInstantiate(HxdLibSpi spi)
  {
    spi.type == null ? ResHxLib() : spi.type.make
  }

  private new make(HxdRuntime rt, HxdInstalledLib install, Dict rec) : super(rt.libsActorPool)
  {
    this.rt      = rt
    this.name    = install.name
    this.install = install
    this.type    = install.type
    this.log     = Log.get(name)
    this.recRef  = AtomicRef(typedRec(rec))
    this.webUri  = ("/" + (name.startsWith("hx") ? name[2..-1].decapitalize : name) + "/").toUri
  }

//////////////////////////////////////////////////////////////////////////
// HxLibSpi Implementation
//////////////////////////////////////////////////////////////////////////

  HxLib lib() { libRef.val }
  private const AtomicRef libRef := AtomicRef()

  override const HxRuntime rt

  override const Str name

  const HxdInstalledLib install

  const Type? type

  override Lib def() { rt.ns.lib(name) }

  override Dict rec() { recRef.val }
  private const AtomicRef recRef

  override const Log log

  override const Uri webUri

//////////////////////////////////////////////////////////////////////////
// Observables
//////////////////////////////////////////////////////////////////////////

  override Subscription[] subscriptions() { subscriptionsRef.val }
  private const AtomicRef subscriptionsRef := AtomicRef(Subscription#.emptyList)

  override Subscription observe(Str name, Dict config, Obj callback)
  {
    observer := callback is Actor ? HxdLibActorObserver(lib, callback) : HxdLibMethodObserver(lib, callback)
    sub := rt.observable(name).subscribe(observer, config)
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

  Void update(Dict rec)
  {
    recRef.val = typedRec(rec)
    send(HxMsg("recUpdate", null))
  }

  Dict typedRec(Dict dict)
  {
    if (type == null) return dict
    recType := type.method("rec").returns
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
        log.err("HxLib.onHouseKeeping", e)
      scheduleHouseKeeping
      return null
    }

    try
    {
      msg := (HxMsg)msgObj
      if (msg.id === "start")       return onStart
      if (msg.id === "ready")       return onReady
      if (msg.id === "steadyState") return onSteadyState
      if (msg.id === "unready")     return onUnready
      if (msg.id === "stop")        return onStop
      if (msg.id === "recUpdate")   return onRecUpdate
      if (msg.id === "sync")        return "synced"
      throw Err(msg.id)
    }
    catch (Err e) log.err("HxLib callback", e)
    return null
  }

  private Obj? onStart()
  {
    isRunningRef.val = true
    lib.onStart
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
    lib.onUnready
    return null
  }

  private Obj? onStop()
  {
    lib.onStop
    isRunningRef.val = false
    return null
  }

  private Obj? onRecUpdate()
  {
    lib.onRecUpdate
    return null
  }

  Bool isRunning() { isRunningRef.val }
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

**************************************************************************
** HxdLibActorObserver
**************************************************************************

internal const class HxdLibActorObserver : Observer
{
  new make(HxLib lib, Actor actor)
  {
    this.lib = lib
    this.actor = actor
    this.meta = Etc.emptyDict
  }

  const HxLib lib
  override const Dict meta
  override const Actor actor
  override Str toStr() { "HxLib $lib.name" }
}

**************************************************************************
** HxdLibMethodObserver
**************************************************************************

internal const class HxdLibMethodObserver : Actor, Observer
{
  new make(HxLib lib, Method method) : super(lib.rt.libs.actorPool)
  {
    this.lib = lib
    this.method = method
    this.meta = Etc.emptyDict
  }

  const HxLib lib
  const Method method
  override const Dict meta
  override Actor actor() { this }
  override Str toStr() { "HxLib $lib.name" }

  override Obj? receive(Obj? msg)
  {
    try
      method.callOn(lib, [msg])
    catch (Err e)
      lib.log.err("${lib.typeof}.observe", e)
    return null
  }
}

