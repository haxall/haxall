//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//    8 Jul 2025  Brian Frank  Redesign from HxLib
//

using concurrent
using xeto
using haystack
using obs

**
** Base class for all Haxall extensions.
**
abstract const class Ext
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Framework use only. Subclasses must declare public no-arg constructor.
  new make()
  {
    this.spiRef = Actor.locals["hx.spi"] as ExtSpi ?: throw Err("Invalid make context")
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

  ** Programmatic name of the extension
  Str name() { spi.name }

  ** Definition meta data.  Not available in constructor.
  @NoDoc virtual DefLib def() { spi.def }

  ** Database record which enables this extension and stores settings.
  ** This field may be overridden with a `haystack::TypedDict` subclass.
  ** Also see `docHaxall::Libs#settings`.
  virtual Dict rec() { spi.rec}

  ** Logger to use for this extension
  Log log() { spi.log }

  ** Web service handling for this extension
  virtual ExtWeb web() { UnsupportedExtWeb(this) }

  ** Return list of services this library publishes.  This callback
  ** is made during initialization and each time a lib is added/removed
  ** from the runtime.
  virtual HxService[] services() { HxService#.emptyList }

  ** Initialize a feed from a subscription request for this library
  @NoDoc virtual HxFeed feedInit(Dict req, HxContext cx)
  {
    throw Err("Ext does not support feedInit: $name")
  }

  ** Service provider interface
  @NoDoc virtual ExtSpi spi() { spiRef }
  @NoDoc const ExtSpi spiRef

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
** ExtSpi
**************************************************************************

**
** Ext service provider interface
**
@NoDoc
const mixin ExtSpi
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

