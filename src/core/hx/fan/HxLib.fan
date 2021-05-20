//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//

using concurrent
using haystack

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
abstract const class HxLib
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Framework use only. Subclasses must declare public no-arg constructor.
  new make()
  {
    this.spi = Actor.locals["hx.spi"] as HxLibSpi ?: throw Err("Invalid make context")
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
  HxRuntime rt() { spi.rt }

  ** Programmatic name key of the library
  Str name() { spi.name }

  ** Definition meta data
  Lib def() { spi.def }

  ** Database record which enables this library and stores settings
  Dict rec() { spi.rec}

  ** Logger to use for this library
  Log log() { spi.log }

  ** Service provider interface
  @NoDoc const HxLibSpi spi

//////////////////////////////////////////////////////////////////////////
// Lifecycle Callbacks
//////////////////////////////////////////////////////////////////////////

  ** Callback when library is started.
  ** This is called on dedicated background actor.
  virtual Void onStart() {}

  ** Callback when library is stopped.
  ** This is called on dedicated background actor.
  virtual Void onStop() {}

  ** Callback when runtime reaches steady state.
  ** This is called on dedicated background actor.
  virtual Void onSteadyState() {}

  ** Callback when associated database `rec` is modified.
  ** This is called on dedicated background actor.
  virtual Void onUpdate() {}
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
  abstract Lib def()
  abstract Dict rec()
  abstract Log log()
}

