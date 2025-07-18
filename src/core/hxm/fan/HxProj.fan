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
** Haxall base implementation of Proj
**
abstract const class HxProj : Proj
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Boot constructor
  new make(HxBoot boot)
  {
    this.name          = boot.name
    this.id            = Ref("p:$name", name)
    this.dir           = boot.dir
    this.db            = boot.db
    this.db.hooks      = HxFolioHooks(this)
    this.log           = boot.log
    this.metaRef       = AtomicRef(boot.meta)
    this.libsActorPool = ActorPool { it.name = "Hx-Exts" }
    this.hxdActorPool  = ActorPool { it.name = "Hx-Runtime" }
    this.backgroundMgr = HxBackgroundMgr(this)
    this.libsRef       = HxProjLibs(this, boot)
    this.extsRef       = HxProjExts(this, libsActorPool)
    this.watchRef      = HxProjWatches(this)
    this.obsRef        = HxProjObservables(this)
  }

  ** Called after constructor to init extensions.  This is
  ** called automatically after boot, but can be called safely
  ** by subclasses in their constructors if they need access to exts
  This init(HxBoot boot)
  {
    // use flag to make this re-entrant to give subclasses flexiblity
    // to finish their initialization before creating exts
    if (inited.val) return this
    inited.val = true

    // initialize
    ns := libsRef.init
    extsRef.init(ns)
    obsRef.init
    return this
  }
  private const AtomicBool inited := AtomicBool()

//////////////////////////////////////////////////////////////////////////
// Proj
//////////////////////////////////////////////////////////////////////////

  ** Return false by default
  override Bool isSys() { false }

  ** If formatted as "p:name"
  override const Ref id

  ** Project name
  override const Str name

  ** Project display name
  override Str dis() { meta["dis"] ?: name }

  ** Project name
  override Str toStr() { name }

  ** Project directory.  It the root directory of all project
  ** oriented operational files.  The folio database is stored under
  ** this directory in a sub-directory named 'db/'.
  override const File dir

  ** Runtime level meta data stored in the `projMeta` database record
  override Dict meta() { metaRef.val }
  internal const AtomicRef metaRef

  ** Database for this runtime
  override const Folio db

  ** Project xeto library management
  override ProjLibs libs() { libsRef }
  const HxProjLibs libsRef

  ** Xeto lib namespace
  override Namespace ns() { libsRef.ns }

  ** Project spec management
  override ProjSpecs specs() { libsRef.specs }

  ** Convenience for 'exts.get' to lookup extension by lib dotted name
  override Ext? ext(Str name, Bool checked := true) { exts.get(name, checked) }

  ** Project extensions
  override ProjExts exts() { extsRef }
  const HxProjExts extsRef

  ** Project watch management
  override ProjWatches watch() { watchRef }
  internal const HxProjWatches watchRef

  ** Project observable management
  override ProjObservables obs() { obsRef }
  const HxProjObservables obsRef

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
        nsBaseRef.val = base = HxDefCompiler(this).compileNamespace

      // compile overlay
// TODO
      nsOverlayRef.val = overlay = base // TODO ProjOverlayCompiler(this, base).compileNamespace
    }
    return overlay
  }
  internal Void defsRecompile() { this.nsBaseRef.val = null; this.nsOverlayRef.val = null }
  internal Void nsOverlayRecompile() { this.nsOverlayRef.val = null }
  private const AtomicRef nsBaseRef := AtomicRef()    // base from installed libs
  private const AtomicRef nsOverlayRef := AtomicRef() // rec overlay

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
    obsRef.sync(timeout)
    return this
  }

  ** Background tasks
  const HxBackgroundMgr backgroundMgr

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

    // Synchronously startup all projects
    startProjs

    // onReady callback
    futures = exts.list.map |lib->Future| { ((HxExtSpi)lib.spi).ready }
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
    futures := exts.list.map |lib->Future| { ((HxExtSpi)lib.spi).unready }
    Future.waitForAll(futures)

    // Synchronously shutdown all projects
    stopProjs

    // onStop callback
    futures = exts.list.map |lib->Future| { ((HxExtSpi)lib.spi).stop }
    Future.waitForAll(futures)

    // kill actor pools
    libsActorPool.kill
    hxdActorPool.kill
  }

  ** Callback for systems to open/start projects
  protected virtual Void startProjs() {}

  ** Callback for systems to stop/close projects
  protected virtual Void stopProjs() {}

  ** Function that calls stop
  const |->| shutdownHook := |->| { stop }

  private const AtomicBool isRunningRef := AtomicBool()
  private const AtomicBool isStarted := AtomicBool()
  private const AtomicBool isStopped  := AtomicBool()

//////////////////////////////////////////////////////////////////////////
// Overrides
//////////////////////////////////////////////////////////////////////////

  ** Called when the libs are modified
  virtual Void onLibsModified(HxNamespace ns)
  {
    extsRef.onLibsModified(ns)
    defsRecompile
  }

  ** Cache for ion project cache
  override once Obj ionData()
  {
    Type.find("ionExt::IonProjData").make([this])
  }

}

