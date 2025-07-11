//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2021  Brian Frank  Creation
//

using concurrent
using web
using xeto
using haystack
using folio
using obs
using hx
using hxm

**
** Haxall daemon implementation of HxRuntime
**
const class HxdRuntime : HxRuntime
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Boot constructor
  new make(HxdBoot boot)
  {
    this.name          = Etc.toTagName(boot.name ?: boot.dir.name)
    this.version       = boot.version
    this.platform      = boot.platformRef
    this.config        = HxConfig(Etc.makeDict(boot.config))
    this.dir           = boot.dir
    this.db            = boot.db
    this.db.hooks      = HxdFolioHooks(this)
    this.log           = boot.log
    this.metaRef       = AtomicRef(boot.projMeta)
    this.installedRef  = AtomicRef(HxdInstalled.build)
    this.libsActorPool = ActorPool { it.name = "Hxd-Lib" }
    this.hxdActorPool  = ActorPool { it.name = "Hxd-Runtime" }
    this.libsOld       = HxdRuntimeLibs(this, boot.requiredLibs)
    this.backgroundMgr = HxdBackgroundMgr(this)
    this.context       = HxdContextService(this)
    this.watch         = HxdWatchService(this)
    this.obs           = HxdObsService(this)
    this.file          = HxdFileService(this)
    this.his           = HxdHisService(this)
    this.shimLibs      = ShimNamespaceMgr.init(dir)
  }

  ** Called after constructor to init libs
  This init(HxdBoot boot)
  {
    libsOld.init(boot.removeUnknownLibs)
    obs.init
    return this
  }

//////////////////////////////////////////////////////////////////////////
// TODO Shims
//////////////////////////////////////////////////////////////////////////

  override Namespace ns() { shimLibs.ns }

  const override ShimNamespaceMgr shimLibs

//////////////////////////////////////////////////////////////////////////
// HxRuntime
//////////////////////////////////////////////////////////////////////////

  ** Runtime name
  override const Str name

  ** Runtime display name
  override Str dis() { meta["dis"] ?: name }

  ** Runtime version
  override const Version version

  ** Platform hosting the runtime
  override const HxPlatform platform

  ** Configuration options defined at bootstrap
  override const HxConfig config

  ** Runtime project directory.  It the root directory of all project
  ** oriented operational files.  The folio database is stored under
  ** this directory in a sub-directory named 'db/'.
  override const File dir

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
        nsBaseRef.val = base = HxdDefCompiler(this).compileNamespace

      // compile overlay
      nsOverlayRef.val = overlay = HxdOverlayCompiler(this, base).compileNamespace
    }
    return overlay
  }
  internal Void nsBaseRecompile() { this.nsBaseRef.val = null; this.nsOverlayRef.val = null }
  internal Void nsOverlayRecompile() { this.nsOverlayRef.val = null }
  private const AtomicRef nsBaseRef := AtomicRef()    // base from installed libs
  private const AtomicRef nsOverlayRef := AtomicRef() // rec overlay

  ** Database for this runtime
  override const Folio db

  ** Runtime level meta data stored in the `projMeta` database record
  override Dict meta() { metaRef.val }
  internal const AtomicRef metaRef

  ** Service registry
  override HxdServiceRegistry services() { servicesRef.val ?: throw Err("Services not avail yet") }
  internal Void servicesRebuild() { servicesRef.val = HxdServiceRegistry(this, libsOld.list) }
  private const AtomicRef servicesRef := AtomicRef(null)

  // HxStdServices conveniences
  override const HxdContextService context
  override const HxdObsService obs
  override const HxWatchService watch
  override const HxFileService file
  override const HxHisService his
  override HxCryptoService crypto() { services.crypto }
  override HxHttpService http() { services.http }
  override HxUserService user() { services.user }
  override HxIOService io() { services.io }
  override HxTaskService task() { services.task }
  override HxPointWriteService pointWrite() { services.pointWrite }
  override HxConnService conn() { services.conn }

  ** Library managment
  override const HxdRuntimeLibs libsOld

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
  internal const HxdBackgroundMgr backgroundMgr

  ** Installed lib pods on the host system
  HxdInstalled installed() { installedRef.val }
  private const AtomicRef installedRef

  ** Logging
  const Log log

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
    futures := libsOld.list.map |lib->Future| { ((MExtSpi)lib.spi).start }
    Future.waitForAll(futures)

    // onReady callback
    futures = libsOld.list.map |lib->Future| { ((MExtSpi)lib.spi).ready }
    Future.waitForAll(futures)

    // kick off background processing
    backgroundMgr.start

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
    futures := libsOld.list.map |lib->Future| { ((MExtSpi)lib.spi).unready }
    Future.waitForAll(futures)

    // onStop callback
    futures = libsOld.list.map |lib->Future| { ((MExtSpi)lib.spi).stop }
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

