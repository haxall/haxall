//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using obs

**
** Base class for all Haxall library runtime instances.  All Haxall libs
** must be standard Haystack 4 libs.  This class is used to model the
** instance of the library within a `HxRuntime` to provide runtime services.
**
** To create a new library:
**   1. Create a pod with a standard Haystack 4 "lib/lib.trio" definition
**   2. Register the lib name using the indexed prop "ph.lib"
**   3. Create subclass of HxLib
**   4. Ensure your lib definition has 'typeName' tag for subclass qname
**
** Also see `docHaxall::Libs`.
**
abstract const class HxLib
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Framework use only. Subclasses must declare public no-arg constructor.
  new make()
  {
    this.spiRef = Actor.locals["hx.spi"] as HxLibSpi ?: throw Err("Invalid make context")
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Identity hash
  override final Int hash() { super.hash }

  ** Equality is based on reference equality
  override final Bool equals(Obj? that) { this === that }

  ** Return `name`
  override final Str toStr() { name }

  ** Runtime
  virtual HxRuntime rt() { spi.rt }

  ** Programmatic name of the library
  Str name() { spi.name }

  ** Definition meta data.  Not available in constructor.
  @NoDoc virtual DefLib def() { spi.def }

  ** Database record which enables this library and stores settings.
  ** This field may be overridden with a `haystack::TypedDict` subclass.
  ** Also see `docHaxall::Libs#settings`.
  virtual Dict rec() { spi.rec}

  ** Logger to use for this library
  Log log() { spi.log }

  ** Web service handling for this library
  virtual HxLibWeb web() { UnsupportedHxLibWeb(this) }

  ** Return list of services this library publishes.  This callback
  ** is made during initialization and each time a lib is added/removed
  ** from the runtime.
  virtual HxService[] services() { HxService#.emptyList }

  ** Initialize a feed from a subscription request for this library
  @NoDoc virtual HxFeed feedInit(Dict req, HxContext cx)
  {
    throw Err("HxLib does not support feedInit: $name")
  }

  ** Service provider interface
  @NoDoc virtual HxLibSpi spi() { spiRef }
  @NoDoc const HxLibSpi spiRef

//////////////////////////////////////////////////////////////////////////
// Observables
//////////////////////////////////////////////////////////////////////////

  ** Return list of observables this extension publishes.  This method
  ** must be overridden as a const field and set in the constructor.
  virtual Observable[] observables() { Observable#.emptyList }

  ** Observable subscriptions for this extension
  Subscription[] subscriptions() { spi.subscriptions }

  ** Subscribe this library to an observable. The callback must be an
  ** Actor instance or Method literal on this class.  If callback is a
  ** method, then its called on the lib's dedicated background actor.
  ** pool. This method should be called in the `onStart` callback.
  ** The observation is automatically unsubscribed on stop.  You should
  ** **not** unsubscribe this subscription - it must be managed by the
  ** extension itself.  See `docHaxall::Observables#fantomObserve`.
  Subscription observe(Str name, Dict config, Obj callback) { spi.observe(name, config, callback) }

//////////////////////////////////////////////////////////////////////////
// Lifecycle Callbacks
//////////////////////////////////////////////////////////////////////////

  ** Running flag.  On startup this flag transitions to true before calling
  ** ready and start on the library.  On shutdown this flag transitions
  ** to false before calling unready and stop on the library.
  Bool isRunning() { spi.isRunning }

  ** Callback when library is started.
  ** This is called on dedicated background actor.
  virtual Void onStart() {}

  ** Callback when all libs are fully started.
  ** This is called on dedicated background actor.
  virtual Void onReady() {}

  ** Callback before we stop the runtime
  ** This is called on dedicated background actor.
  virtual Void onUnready() {}

  ** Callback when library is stopped.
  ** This is called on dedicated background actor.
  virtual Void onStop() {}

  ** Callback when runtime reaches steady state.
  ** This is called on dedicated background actor.
  virtual Void onSteadyState() {}

  ** Callback when associated database `rec` is modified.
  ** This is called on dedicated background actor.
  virtual Void onRecUpdate() {}

  ** Callback made periodically to perform background tasks.
  ** Override `houseKeepingFreq` to enable the frequency of this callback.
  virtual Void onHouseKeeping() {}

  ** Override to return non-null for onHouseKeeping callback
  virtual Duration? houseKeepingFreq() { null }

  ** Callback to handle a non-standard actor message to this library.
  @NoDoc virtual Obj? onReceive(HxMsg msg)
  {
    throw UnsupportedErr("Unknown msg: $msg")
  }
}

**************************************************************************
** HxLibSpi
**************************************************************************

**
** HxLib service provider interface
**
@NoDoc
const mixin HxLibSpi
{
  abstract HxRuntime rt()
  abstract Str name()
  abstract DefLib def()
  abstract Dict rec()
  abstract Log log()
  abstract Uri webUri()
  abstract Bool isRunning()
  abstract Actor actor()
  abstract Void sync(Duration? timeout := 30sec)
  abstract Subscription[] subscriptions()
  abstract Subscription observe(Str name, Dict config, Obj callback)
  abstract Bool isFault()
  abstract Void toStatus(Str status, Str msg)
}

