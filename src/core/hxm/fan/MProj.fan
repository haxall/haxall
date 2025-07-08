//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Jul 2025  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using hx
using hx4

**
** Proj implementation
**
const class MProj : Proj
{
  new make(Boot boot)
  {
    this.name         = boot.name
    this.id           = Ref("p:$name", name)
    this.dir          = boot.dir
    this.meta         = boot.meta
    this.ns           = boot.ns
    this.db           = boot.db
    this.extActorPool = ActorPool { it.name = "$this.name-ExtPool" }
    this.exts         = MProjExts(this, boot.requiredLibs)
    this.log          = Log.get(name)
    exts.init(ns.exts.list)
  }

//////////////////////////////////////////////////////////////////////////
// Proj
//////////////////////////////////////////////////////////////////////////

  const override Str name
  const override Ref id
  const override Dict meta
  const override File dir
  const override Namespace ns
  const override Folio db
  const override MProjExts exts
  override final Str toStr() { name }

  const Log log
  const ActorPool extActorPool

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** If the project currently running
  Bool isRunning() { isRunningRef.val }

  ** Start project (blocks until all exts fully started)
  This start()
  {
    // this method can only be called once
    if (isStarted.getAndSet(true)) return this

    // set running flag
    isRunningRef.val = true

    // onStart callback
    futures := exts.list.map |ext->Future| { ((MExtSpi)ext.spi).start }
    Future.waitForAll(futures)

    // onReady callback
    futures = exts.list.map |ext->Future| { ((MExtSpi)ext.spi).ready }
    Future.waitForAll(futures)

    // kick off background processing
    // TODO
    //backgroundMgr.start

    return this
  }

  ** Shutdown the system (blocks until all exts stop)
  Void stop()
  {
    // this method can only be called once
    if (isStopped.getAndSet(true)) return this

    // clear running flag
    isRunningRef.val = false

    // onUnready callback
    futures := exts.list.map |ext->Future| { ((MExtSpi)ext.spi).unready }
    Future.waitForAll(futures)

    // onStop callback
    futures = exts.list.map |ext->Future| { ((MExtSpi)ext.spi).stop }
    Future.waitForAll(futures)

    // kill actor pools
    extActorPool.kill
  }


  private const AtomicBool isRunningRef := AtomicBool()
  private const AtomicBool isStarted := AtomicBool()
  private const AtomicBool isStopped  := AtomicBool()
}

