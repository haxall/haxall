//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2021  Brian Frank  Creation
//

using concurrent
using web
using haystack
using folio
using obs
using hx

**
** Haxall daemon implementation of HxRuntime
**
const class HxdRuntime : HxRuntime
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Boot constructor
  internal new make(HxdBoot boot)
  {
    this.name          = Etc.toTagName(boot.dir.name)
    this.version       = boot.version
    this.platform      = boot.platformRef
    this.db            = boot.db
    this.db.hooks      = HxdFolioHooks(this)
    this.log           = boot.log
    this.installedRef  = AtomicRef(HxdInstalled.build)
    this.libsActorPool = ActorPool { it.name = "Hxd-Lib" }
    this.hxdActorPool  = ActorPool { it.name = "Hxd-Runtime" }
    this.libs          = HxdRuntimeLibs(this, boot.requiredLibs)
    this.backgroundMgr = HxdBackgroundMgr(this)
    this.observables   = HxdObserveMgr(this)
//    this.watches       = HxdWatchMgr(this)
    libs.init
    this.users         = (HxRuntimeUsers)libs.getType(HxRuntimeUsers#)
  }

//////////////////////////////////////////////////////////////////////////
// HxRuntime
//////////////////////////////////////////////////////////////////////////

  ** Runtime version
  override const Str name

  ** Runtime version
  override const Version version

  ** Platform hosting the runtime
  override const HxPlatform platform

  ** Namespace of definitions
  override Namespace ns()
  {
    // lazily compile as needed
    overlay := nsOverlayRef.val as Namespace
    if (overlay == null)
    {
      // lazily recompile base
      base := nsBaseRef.val as Namespace
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

  ** Lookup a library by name
  override HxLib? lib(Str name, Bool checked := true) { libs.get(name, checked) }

  ** Library managment
  override const HxdRuntimeLibs libs

  ** Has the runtime has reached steady state.
  override Bool isSteadyState() { stateStateRef.val }
  internal const AtomicBool stateStateRef := AtomicBool(true)

  ** Actor pool to use for HxRuntimeLibs.actorPool
  const ActorPool libsActorPool

  ** Actor pool to use for core daemon functionality
  const ActorPool hxdActorPool

  ** List the published observables for this runtime
  override const HxdObserveMgr observables

  ** Watch subscription APIs
//  override const HxRuntimeWatches watches

  ** Block until currently queued background processing completes
  override This sync(Duration? timeout := 30sec)
  {
    db.sync(timeout)
    observables.sync(timeout)
    return this
  }

  ** Background tasks
  internal const HxdBackgroundMgr backgroundMgr

  ** Public HTTP or HTTPS URI of this host.  This is always
  ** an absolute URI such 'https://acme.com/'
  override Uri siteUri() { `http://localhost:8080/` } // TODO

  ** URI on this host to the Haystack HTTP API.  This is always
  ** a host relative URI which end withs a slash such '/api/'.
  override Uri apiUri() { `/api/` }

  ** User and authentication managment
  override const HxRuntimeUsers users

  ** Construct a runtime specific context for the given user account
  override HxContext makeContext(HxUser user) { HxdContext(this, user) }

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
  Bool isRunning() { isRunningRef.val }

  ** Start runtime (blocks until all libs fully started)
  This start()
  {
    // this method can only be called once
    if (isStarted.getAndSet(true)) return this

    // set running flag
    isRunningRef.val = true

    // onStart callback
    futures := libs.list.map |lib->Future| { ((HxdLibSpi)lib.spi).start }
    Future.waitForAll(futures)

    // onReady callback
    futures = libs.list.map |lib->Future| { ((HxdLibSpi)lib.spi).ready }
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
    futures := libs.list.map |lib->Future| { ((HxdLibSpi)lib.spi).unready }
    Future.waitForAll(futures)

    // onStop callback
    futures = libs.list.map |lib->Future| { ((HxdLibSpi)lib.spi).stop }
    Future.waitForAll(futures)
  }

  ** Function that calls stop
  const |->| shutdownHook := |->| { stop }

  private const AtomicBool isRunningRef := AtomicBool()
  private const AtomicBool isStarted := AtomicBool()
  private const AtomicBool isStopped  := AtomicBool()

}

