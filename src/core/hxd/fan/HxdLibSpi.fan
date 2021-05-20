//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hx

const class HxdLibSpi : Actor, HxLibSpi
{

//////////////////////////////////////////////////////////////////////////
// HxLib Factory
//////////////////////////////////////////////////////////////////////////

  ** Instantiate the HxLib for given def and database rec
  static HxLib instantiate(HxdRuntime rt, Lib def, Dict rec)
  {
    spi := HxdLibSpi(rt, def.name, rec)
    Actor.locals["hx.spi"]  = spi
    try
    {
      lib := doInstantiate(def)
      spi.libRef.val = lib
      return lib
    }
    finally
    {
      Actor.locals.remove("hx.spi")
    }
  }

  private static HxLib doInstantiate(Lib def)
  {
    typeName := def["typeName"] as Str
    if (typeName == null) return ResHxLib()
    return Type.find(typeName).make
  }

  private new make(HxdRuntime rt, Str name, Dict rec) : super(rt.libActorPool)
  {
    this.rt     = rt
    this.name   = name
    this.recRef = AtomicRef(rec)
    this.log    = Log.get(name)
  }

//////////////////////////////////////////////////////////////////////////
// HxLibSpi Implementation
//////////////////////////////////////////////////////////////////////////

  HxLib lib() { libRef.val }
  private const AtomicRef libRef := AtomicRef()

  override const HxRuntime rt

  override const Str name

  override Lib def() { rt.ns.lib(name) }

  override Dict rec() { recRef.val }
  private const AtomicRef recRef

  override const Log log

//////////////////////////////////////////////////////////////////////////
// Background Processing
//////////////////////////////////////////////////////////////////////////

  Future start() { send(HxMsg("start"))  }

  Future ready() { send(HxMsg("ready")) }

  Future steadyState() { send(HxMsg("steadyState")) }

  Future unready() { send(HxMsg("unready")) }

  Future stop() { send(HxMsg("stop")) }

  Void sync(Duration timeout := 30sec) { send((HxMsg("sync"))).get(timeout) }

  Void update(Dict rec)
  {
    recRef.val = rec
    send(HxMsg("update", null))
  }

  override Obj? receive(Obj? msgObj)
  {
    try
    {
      msg := (HxMsg)msgObj
      if (msg.id === "start")       return onStart
      if (msg.id === "ready")       return onReady
      if (msg.id === "steadyState") return onSteadyState
      if (msg.id === "unready")     return onUnready
      if (msg.id === "stop")        return onStop
      if (msg.id === "update")      return onUpdate
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
    if (lib is HxdLib) ((HxdLib)lib).onReady
    return null
  }

  private Obj? onSteadyState()
  {
    lib.onSteadyState
    return null
  }

  private Obj? onUnready()
  {
    if (lib is HxdLib) ((HxdLib)lib).onUnready
    return null
  }

  private Obj? onStop()
  {
    lib.onStop
    isRunningRef.val = false
    return null
  }

  private Obj? onUpdate()
  {
    lib.onUpdate
    return null
  }

  Bool isRunning() { isRunningRef.val }
  private const AtomicBool isRunningRef := AtomicBool(false)

}

**************************************************************************
** ResHxLib
**************************************************************************

** ResHxLib is a stub for libraries without a Fantom class
const class ResHxLib : HxLib
{
}