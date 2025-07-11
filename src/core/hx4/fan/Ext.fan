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
using folio
using obs
using hx

/*
**
** Base class for all Haxall service extensions
**
abstract const class Ext
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Subclasses must declare public no-arg constructor
  new make()
  {
    this.spiRef = Actor.locals["hx.spi"] as ExtSpi ?: throw Err("Invalid make context")
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Identity hash
  override final Int hash() { qname.hash }

  ** Equality is based on reference equality
  override final Bool equals(Obj? that) { this === that }

  ** Return `qname`
  override final Str toStr() { qname }

  ** Project
  virtual Proj proj() { spi.proj }

  ** Qualified name of the extension's spec
  Str qname() { spi.qname }

  ** Settings or empty dict
  virtual Dict settings() { spi.settings }

  ** Logger to use for this extension
  Log log() { spi.log }

  ** Service provider interface
  @NoDoc virtual ExtSpi spi() { spiRef }
  @NoDoc const ExtSpi spiRef

//////////////////////////////////////////////////////////////////////////
// Observables
//////////////////////////////////////////////////////////////////////////

  ** Return list of observables this extension publishes.  This method
  ** must be overridden as a const field and set in the constructor.
  /*
  virtual Observable[] observables() { Observable#.emptyList }

  ** Observable subscriptions for this extension
  Subscription[] subscriptions() { spi.subscriptions }

  ** Subscribe this extension to an observable. The callback must be an
  ** Actor instance or Method literal on this class.  If callback is a
  ** method, then its called on the ext's dedicated background actor.
  ** pool. This method should be called in the `onStart` callback.
  ** The observation is automatically unsubscribed on stop.  You should
  ** **not** unsubscribe this subscription - it must be managed by the
  ** extension itself.  See `docHaxall::Observables#fantomObserve`.
  Subscription observe(Str name, Dict config, Obj callback) { spi.observe(name, config, callback) }
  */

//////////////////////////////////////////////////////////////////////////
// Lifecycle Callbacks
//////////////////////////////////////////////////////////////////////////

  ** Running flag.  On startup this flag transitions to true before
  ** calling start/ready on the extension.  On shutdown this flag transitions
  ** to false before calling unready/stop on the extension.
  Bool isRunning() { spi.isRunning }

  ** Callback when extension is started.
  ** This is called on dedicated background actor.
  virtual Void onStart() {}

  ** Callback when all extensions are fully started.
  ** This is called on dedicated background actor.
  virtual Void onReady() {}

  ** Callback before we stop the extension
  ** This is called on dedicated background actor.
  virtual Void onUnready() {}

  ** Callback when extension is stopped.
  ** This is called on dedicated background actor.
  virtual Void onStop() {}

  ** Callback when project reaches steady state.
  ** This is called on dedicated background actor.
  virtual Void onSteadyState() {}

  ** Callback when associated extension settings are modified.
  ** This is called on dedicated background actor.
  virtual Void onSettings() {}

  ** Callback made periodically to perform background tasks.
  ** Override `houseKeepingFreq` to enable the frequency of this callback.
  virtual Void onHouseKeeping() {}

  ** Override to return non-null for onHouseKeeping callback
  virtual Duration? houseKeepingFreq() { null }

  ** Callback to handle a non-standard actor message to this extension.
  @NoDoc virtual Obj? onReceive(HxMsg msg)
  {
    throw UnknownMsgErr(msg.toStr)
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
  abstract Proj proj()
  abstract Str qname()
  abstract Dict settings()
  abstract Log log()
  abstract Bool isRunning()
  abstract Actor actor()
  abstract Void sync(Duration? timeout := 30sec)
  abstract Bool isFault()
  abstract Void toStatus(Str status, Str msg)
}
*/

