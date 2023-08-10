//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 2022  Brian Frank  Creation
//

using util
using concurrent
using xeto
using haystack::UnknownLibErr

**
** MRegistry manages the cache and loading of the environments libs
**
@Js
abstract const class MRegistry : LibRegistry
{

  ** Load the given library synchronously
  abstract Lib? loadSync(Str qname, Bool checked := true)

  ** Load the given library asynchronously
  abstract Void loadAsync(Str qname, |Lib?| f)

}

**************************************************************************
** MRegistryEntry
**************************************************************************

**
** LibRegistryEntry implementation base class
**
@Js
abstract const class MRegistryEntry : LibRegistryEntry
{
  override Bool isLoaded() { libRef.val != null }

  XetoLib get() { libRef.val ?: throw Err("Not loaded: $name") }

  Void set(Lib lib) { libRef.compareAndSet(null, lib) }

  private const AtomicRef libRef := AtomicRef()
}


