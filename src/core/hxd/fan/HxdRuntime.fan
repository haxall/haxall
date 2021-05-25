//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2021  Brian Frank  Creation
//

using concurrent
using haystack
using folio
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
    this.version      = boot.version
    this.db           = boot.db
    this.log          = boot.log
    this.installedRef = AtomicRef(HxdInstalled.build)
    this.nsRef.val    = HxdDefCompiler(db, log).compileNamespace
    this.libActorPool = ActorPool { it.name = "Hxd-Lib" }
    this.libMgr       = HxdLibMgr(this, boot.requiredLibs)
  }

//////////////////////////////////////////////////////////////////////////
// HxRuntime
//////////////////////////////////////////////////////////////////////////

  ** Runtime version
  override const Version version

  ** Namespace of definitions
  override Namespace ns() { nsRef.val }
  private const AtomicRef nsRef := AtomicRef()

  ** Database for this runtime
  override const Folio db

  ** Actor thread pool for libraries
  override const ActorPool libActorPool

  ** List of libs currently enabled
  override HxLib[] libs() { libMgr.list }

  ** Lookup an enabled lib by name.  If not found then
  ** return null or raise UnknownLibErr based on checked flag.
  override HxLib? lib(Str name, Bool checked := true) { libMgr.get(name, checked) }

  ** Check if there is an enabled lib with given name
  override Bool hasLib(Str name) { libMgr.hasLib(name) }

  ** Enable a library in the runtime
  override HxLib libAdd(Str name, Dict tags := Etc.emptyDict) { libMgr.add(name, tags) }

  ** Disable a library from the runtime.
  ** The lib arg may be a HxLib instace, Lib definition, or Str name.
  override Void libRemove(Obj lib) { libMgr.remove(lib) }

  ** Installed lib pods on the host system
  HxdInstalled installed() { installedRef.val }
  private const AtomicRef installedRef

  ** Library registry manager
  internal const HxdLibMgr libMgr

  ** Logging
  const Log log

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** Recompile the namespace
  internal Void nsRecompile()
  {
    this.nsRef.val = HxdDefCompiler(db, log).compileNamespace
  }

  ** Start runtime (blocks until all libs fully started)
  This start()
  {
    // this method can only be called once
    if (isStarted.getAndSet(true)) return this

    // onStart callback
    futures := libs.map |lib->Future| { ((HxdLibSpi)lib.spi).start }
    Future.waitForAll(futures)


    // onReady callback
    futures = libs.findAll { it is HxdLib }.map |lib->Future| { ((HxdLibSpi)lib.spi).ready }
    Future.waitForAll(futures)

    return this
  }

  ** Shutdown the system (blocks until all modules stop)
  Void stop()
  {
    // this method can only be called once
    if (isStopped.getAndSet(true)) return this

    // onUnready callback
    futures := libs.findAll { it is HxdLib }.map |lib->Future| { ((HxdLibSpi)lib.spi).unready }
    Future.waitForAll(futures)

    // onStop callback
    futures = libs.map |lib->Future| { ((HxdLibSpi)lib.spi).stop }
    Future.waitForAll(futures)
  }

  ** Function that calls stop
  const |->| shutdownHook := |->| { stop }

  private const AtomicBool isStarted := AtomicBool()
  private const AtomicBool isStopped  := AtomicBool()

}

