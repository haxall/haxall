//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2021  Brian Frank  Creation
//    8 Jul 2025  Brian Frank  Refactoring for 4.0
//

using concurrent
using xeto
using haystack
using folio
using obs
using hx

**
** Haxall implementation of Proj
**
const class HxProj : Proj
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Boot constructor
  new make(HxBoot boot)
  {
    this.name          = boot.name
    this.version       = boot.version
    this.platform      = HxPlatform(Etc.dict0) // TODO
    this.config        = HxConfig(Etc.dict0)   // TODO
    this.dir           = boot.dir
    this.db            = boot.db
//    this.db.hooks      = HxdFolioHooks(this)
    this.log           = boot.log
    this.metaRef       = AtomicRef(boot.meta)
    this.libsActorPool = ActorPool { it.name = "Hx-Exts" }
    this.hxdActorPool  = ActorPool { it.name = "Hx-Runtime" }
//    this.backgroundMgr = HxdBackgroundMgr(this)
//    this.context       = HxdContextService(this)
//    this.file          = HxdFileService(this)
//    this.his           = HxdHisService(this)
    this.libs          = MProjLibs.shim(dir)
    this.exts          = HxProjExts(this, libsActorPool)
    this.watch         = HxProjWatches(this)
    this.obs           = HxProjObservables(this)
libs.rtRef.val = this
init(boot)
  }

  ** Called after constructor to init libs
  This init(HxBoot boot)
  {
    exts.init
    servicesRef.val = boot.initServices(this, exts.list)
//    obs.init
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Proj
//////////////////////////////////////////////////////////////////////////

  ** Runtime name
  override const Str name

  ** Runtime display name
  override Str dis() { meta["dis"] ?: name }

  ** Runtime version
  override const Version version

  ** Host platform metadata
  override const HxPlatform platform := HxPlatform(Etc.dict0)

  ** Configuration options defined at bootstrap
  override const HxConfig config

  ** Runtime project directory.  It the root directory of all project
  ** oriented operational files.  The folio database is stored under
  ** this directory in a sub-directory named 'db/'.
  override const File dir

  ** Runtime level meta data stored in the `projMeta` database record
  override Dict meta() { metaRef.val }
  internal const AtomicRef metaRef

  ** Database for this runtime
  override const Folio db

  ** Project xeto library management
  override const MProjLibs libs

  ** Xeto lib namespace
  override Namespace ns() { libs.ns }

  ** Project spec management
  override ProjSpecs specs() { libs.specs }

  ** Convenience for 'exts.get' to lookup extension by lib dotted name
  override Ext? ext(Str name, Bool checked := true) { exts.get(name, checked) }

  ** Project extensions
  override const HxProjExts exts

  ** Project watch management
  override const ProjWatches watch

  ** Project observable management
  override const HxProjObservables obs

  ** Namespace of definitions
  override DefNamespace defs()
  {
    // lazily compile as needed
    overlay := nsOverlayRef.val as DefNamespace
    if (overlay == null)
    {
      // lazily recompile base
      base := nsBaseRef.val as DefNamespace
      if (base == null)
        nsBaseRef.val = base = ProjDefCompiler(this).compileNamespace

      // compile overlay
      nsOverlayRef.val = overlay = base // TODO ProjOverlayCompiler(this, base).compileNamespace
    }
    return overlay
  }
override Void recompileDefs() { nsBaseRecompile }
  internal Void nsBaseRecompile() { this.nsBaseRef.val = null; this.nsOverlayRef.val = null }
  internal Void nsOverlayRecompile() { this.nsOverlayRef.val = null }
  private const AtomicRef nsBaseRef := AtomicRef()    // base from installed libs
  private const AtomicRef nsOverlayRef := AtomicRef() // rec overlay

  ** Service registry
override HxServiceRegistry services() { servicesRef.val ?: throw Err("Services not avail yet") }
//  override HxdServiceRegistry services() { servicesRef.val ?: throw Err("Services not avail yet") }
//  internal Void servicesRebuild() { servicesRef.val = HxdServiceRegistry(this, exts.list) }
  private const AtomicRef servicesRef := AtomicRef(null)

  // HxStdServices conveniences
/*
  override const HxContextService context
  override const HxObsService obs
  override const HxWatchService watch
  override const HxFileService file
  override const HxHisService his
*/
override HxContextService context() { services.context }
override HxFileService file() { services.file }
override  HxHisService his() { services.his }
  override HxCryptoService crypto() { services.crypto }
  override HxHttpService http() { services.http }
  override HxUserService user() { services.user }
  override HxIOService io() { services.io }
  override HxTaskService task() { services.task }
  override HxPointWriteService pointWrite() { services.pointWrite }
  override HxConnService conn() { services.conn }

  ** Has the runtime has reached steady state.
  override Bool isSteadyState() { stateStateRef.val }
  internal const AtomicBool stateStateRef := AtomicBool(false)

  ** Actor pool to use for HxRuntimeLibs.actorPool
  const ActorPool libsActorPool

  ** Actor pool to use for core daemon functionality
  const ActorPool hxdActorPool

  ** Block until currently queued background processing completes
  override This sync(Duration? timeout := 30sec)
  {
    db.sync(timeout)
    obs.sync(timeout)
    return this
  }

  ** Background tasks
//  internal const HxdBackgroundMgr backgroundMgr

  ** Logging
  override const Log log

//////////////////////////////////////////////////////////////////////////
// Folio Conveniences
//////////////////////////////////////////////////////////////////////////

  override Dict? readById(Ref? id, Bool checked := true) { db.readById(id, checked) }

  override Grid readByIds(Ref[] ids, Bool checked := true) { db.readByIds(ids, checked) }

  override Dict?[] readByIdsList(Ref[] ids, Bool checked := true) { db.readByIdsList(ids, checked) }

  override Int readCount(Str filter) { db.readCount(Filter(filter)) }

  override Dict? read(Str filter, Bool checked := true) { db.read(Filter(filter), checked) }

  override Grid readAll(Str filter, Dict? opts := null) { db.readAll(Filter(filter), opts) }

  override Dict[] readAllList(Str filter, Dict? opts := null) { db.readAllList(Filter(filter), opts) }

  override Diff commit(Diff diff) { db.commit(diff) }

  override Diff[] commitAll(Diff[] diffs) { db.commitAll(diffs) }


//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** Cached DateTime in system timezone accurate within 100ms (background freq)
  DateTime now() { nowRef.val }
  internal const AtomicRef nowRef := AtomicRef(DateTime.now)

  ** If the runtime currently running
  override Bool isRunning() { isRunningRef.val }

  ** Start runtime (blocks until all libs fully started)
  This start()
  {
    // this method can only be called once
    if (isStarted.getAndSet(true)) return this

    // set running flag
    isRunningRef.val = true

    // onStart callback
    futures := exts.list.map |lib->Future| { ((HxExtSpi)lib.spi).start }
    Future.waitForAll(futures)

    // onReady callback
    futures = exts.list.map |lib->Future| { ((HxExtSpi)lib.spi).ready }
    Future.waitForAll(futures)

    // kick off background processing
//    backgroundMgr.start

    return this
  }

  ** Shutdown the system (blocks until all modules stop)
  Void stop()
  {
    // this method can only be called once
    if (isStopped.getAndSet(true)) return this

    // clear running flag
    isRunningRef.val = false

    // onUnready callback
    futures := exts.list.map |lib->Future| { ((HxExtSpi)lib.spi).unready }
    Future.waitForAll(futures)

    // onStop callback
    futures = exts.list.map |lib->Future| { ((HxExtSpi)lib.spi).stop }
    Future.waitForAll(futures)

    // kill actor pools
    libsActorPool.kill
    hxdActorPool.kill
  }

  ** Function that calls stop
  const |->| shutdownHook := |->| { stop }

  private const AtomicBool isRunningRef := AtomicBool()
  private const AtomicBool isStarted := AtomicBool()
  private const AtomicBool isStopped  := AtomicBool()

}

