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
using hxUtil

**
** Haxall base implementation of Runtime
**
abstract const class HxRuntime : Runtime
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
    this.tb            = boot.initTextBase
    this.dbRef         = boot.initFolio
    this.db.hooks      = boot.initFolioHooks(this)
    this.log           = boot.log
    this.actorPool     = boot.actorPool
    this.settingsMgr   = HxSettingsMgr(this, boot)
    this.metaRef       = AtomicRef(settingsMgr.projMetaInit(boot))
    this.backgroundMgr = boot.initBackgroundMgr(this)
    this.libsRef       = boot.initLibs(this)
    this.extsRef       = boot.initExts(this)
    this.watchRef      = boot.initWatches(this)
    this.obsRef        = boot.initObs(this)
  }

  ** Called after constructor to init extensions.  This must
  ** be called after make before start. But it can be called safely
  ** by subclasses in their constructors if they need access to exts
  virtual This init(HxBoot boot)
  {
    // use flag to make this re-entrant to give subclasses flexiblity
    // to finish their initialization before creating exts
    if (inited.val) return this
    inited.val = true

    // initialize
    ns := libsRef.init
    extsRef.init(boot, ns)
    obsRef.init
    return this
  }
  private const AtomicBool inited := AtomicBool()

//////////////////////////////////////////////////////////////////////////
// Proj
//////////////////////////////////////////////////////////////////////////

  ** Return false by default
  override Bool isSys() { false }

  ** Formatted as "p:name"
  override const Ref id

  ** Runtime name
  override const Str name

  ** Runtime display name
  override Str dis() { meta["dis"] ?: name }

  ** Runtime name
  override Str toStr() { name }

  ** Runtime directory.
  override const File dir

  ** Runtime level meta data stored in the `projMeta` database record
  override Dict meta() { metaRef.val }
  internal const AtomicRef metaRef

  ** Update proj metadata with Str:Obj, Dict, or Diff.
  override Void metaUpdate(Obj changes) { settingsMgr.projMetaUpdate(changes) }

  ** TextBase for namespace settings and proj specs managed in plain text
  const TextBase tb

  ** Database for this runtime
  override Folio db() { dbRef }
  const Folio dbRef

  ** Runtime xeto library management
  override RuntimeLibs libs() { libsRef }
  const HxLibs libsRef

  ** Xeto lib namespace
  override Namespace ns() { libsRef.ns }

  ** Convenience for 'exts.get' to lookup extension by lib dotted name
  override Ext? ext(Str name, Bool checked := true) { exts.get(name, checked) }

  ** Project extensions
  override RuntimeExts exts() { extsRef }
  const HxExts extsRef

  ** Runtime watch management
  override RuntimeWatches watch() { watchRef }
  internal const HxWatches watchRef

  ** Runtime observable management
  override RuntimeObservables obs() { obsRef }
  const HxObservables obsRef

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
      nsOverlayRef.val = overlay = HxDefOverlayCompiler(this, base).compileNamespace
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

  ** Actor pool for the project
  const ActorPool actorPool

  ** Block until currently queued background processing completes
  override This sync(Duration? timeout := 30sec)
  {
    db.sync(timeout)
    obsRef.sync(timeout)
    return this
  }

  ** Project/ext settings
  const HxSettingsMgr settingsMgr

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
  virtual This start()
  {
    // validate we are initialized
    if (!inited.val) throw Err("Must call init")

    // this method can only be called once
    if (isStarted.getAndSet(true)) return this

    // set running flag
    isRunningRef.val = true

    // onStart callback
    exts := exts.listOwn
    futures := exts.map |lib->Future| { ((HxExtSpi)lib.spi).start }
    Future.waitForAll(futures)

    // Synchronously startup all projects
    startProjs

    // onReady callback
    futures = exts.map |lib->Future| { ((HxExtSpi)lib.spi).ready }
    Future.waitForAll(futures)

    // kick off background processing
    backgroundMgr.start

    return this
  }

  ** Shutdown the system (blocks until all modules stop)
  virtual This stop()
  {
    // this method can only be called once
    if (isStopped.getAndSet(true)) return this

    // clear running flag
    isRunningRef.val = false

    // onUnready callback
    exts := exts.listOwn
    futures := exts.map |lib->Future| { ((HxExtSpi)lib.spi).unready }
    Future.waitForAll(futures)

    // Synchronously shutdown all projects
    stopProjs

    // onStop callback
    futures = exts.map |lib->Future| { ((HxExtSpi)lib.spi).stop }
    Future.waitForAll(futures)

    // close database
    db.close

    // kill actor pools
    actorPool.kill
    return this
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
    // update extensions
    extsRef.onLibsModified(ns)

    // update defs
    defsRecompile

    // if I am the sys, then all the proj ns need reload too
    if (isSys)
    {
      sys.proj.list.each |Obj proj|
      {
        if (proj !== this) ((HxRuntime)proj).libsRef.reload
      }
    }
  }

  ** Cache for ion project cache
  override once Obj ionData()
  {
    Type.find("ionExt::IonProjData").make([this])
  }

}

