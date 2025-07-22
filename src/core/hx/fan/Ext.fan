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
using folio

**
** Extension
**
const mixin Ext
{

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** System
  virtual Sys sys() { spi.proj.sys }

  ** Project
  virtual Proj proj() { spi.proj }

  ** Library dotted name that identifies the extension
  Str name() { spi.name }

  ** Xeto spec for this extension
  Spec spec() { spi.spec }

  ** TODO: remove in favor of settings
  virtual Dict rec() { spi.settings }

  ** Settings for the extension
  virtual Dict settings() { spi.settings }

  ** Asynchronously update extension settings
  Void settingsUpdate(Diff diff) { spi.settingsUpdate(diff) }

  ** Logger to use for this extension
  Log log() { spi.log }

  ** Web service handling for this extension
  virtual ExtWeb web() { UnsupportedExtWeb(this) }

  ** Initialize a feed from a subscription request for this library
  @NoDoc virtual HxFeed feedInit(Dict req, Context cx)
  {
    throw Err("Ext does not support feedInit: $name")
  }

  ** Service provider interface
  @NoDoc abstract ExtSpi spi()

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

  ** Callback before we stop the project
  ** This is called on dedicated background actor.
  virtual Void onUnready() {}

  ** Callback when extension is stopped.
  ** This is called on dedicated background actor.
  virtual Void onStop() {}

  ** Callback when extension reaches steady state.
  ** This is called on dedicated background actor.
  virtual Void onSteadyState() {}

** TODO
@Deprecated virtual Void onRecUpdate() {}

  ** Callback when associated settings are modified.
  ** This is called on dedicated background actor.
  virtual Void onSettings() {}

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
** ExtObj
**************************************************************************

**
** Base class for all `Ext` implementations
**
abstract const class ExtObj : Ext
{
  ** All subclasses must declare public no-arg constructor.
  new make()
  {
    this.spi = Actor.locals["hx.spi"] as ExtSpi ?: throw Err("Invalid make context")
  }

  ** Identity hash
  override final Int hash() { super.hash }

  ** Equality is based on reference equality
  override final Bool equals(Obj? that) { this === that }

  ** Return `name`
  override final Str toStr() { name }

  @NoDoc
  const override ExtSpi spi
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
  abstract Proj proj()
  abstract Str name()
  abstract Spec spec()
  abstract Dict settings()
  abstract Void settingsUpdate(Diff diff)
  abstract Log log()
  abstract Bool isRunning()
  abstract Actor actor()
  abstract Void sync(Duration? timeout := 30sec)
  abstract Subscription[] subscriptions()
  abstract Subscription observe(Str name, Dict config, Obj callback)
  abstract Bool isFault()
  abstract Void toStatus(Str status, Str msg)
}

