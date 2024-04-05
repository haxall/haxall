//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack::UnknownLibErr

**
** LibNamespace implementation base class
**
@Js
abstract const class MNamespace : LibNamespace
{
  new make(NameTable names, LibVersion[] versions)
  {
    this.names = names
    versions.each |x| { entries.add(x.name, MLibEntry(x)) }

    // TODO: reuse XetoEnv.cur for now
    this.sysLib = XetoEnv.cur.sysLib
    entry("sys").set(this.sysLib)
    if (versions.size == 1) allLoaded.val = true
  }

//////////////////////////////////////////////////////////////////////////
// LibNamespace
//////////////////////////////////////////////////////////////////////////

  const override Lib sysLib

  override LibVersion[] versions()
  {
    acc := LibVersion[,]
    acc.capacity = entries.size
    entries.each |MLibEntry e| { acc.add(e.version) }
    return acc
  }

  override LibVersion? version(Str name, Bool checked :=true)
  {
    entry(name, checked)?.version
  }

  override Bool isLoaded(Str name)
  {
    entry(name, false)?.isLoaded ?: false
  }

  override Bool isAllLoaded()
  {
    allLoaded.val
  }

  override Lib? lib(Str name, Bool checked := true)
  {
    entry(name, checked)?.get(checked)
  }

  override Void libAsync(Str name, |Err?, Lib?| f)
  {
    throw Err("TODO")
  }

  internal MLibEntry? entry(Str name, Bool checked := true)
  {
    entry := entries.get(name) as MLibEntry
    if (entry != null) return entry
    if (checked) throw UnknownLibErr(name)
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Hooks
//////////////////////////////////////////////////////////////////////////

  ** Load the given library synchronously
  abstract Lib? loadSync(Str name, Bool checked := true)

  ** Load the given library asynchronously
  abstract Void loadAsync(Str name, |Err?, Lib?| f)

  ** Load a list of library names asynchronously
  abstract Void loadAsyncList(Str[] names, |Err?| f)

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const NameTable names
  private const ConcurrentMap entries := ConcurrentMap()
  private const AtomicBool allLoaded := AtomicBool()

}

**************************************************************************
**MLibEntry
**************************************************************************

@Js
internal const class MLibEntry
{
  new make(LibVersion version) { this.version = version }

  Str name() { version.name }

  const LibVersion version

  override Int compare(Obj that) { this.name <=> ((MLibEntry)that).name }

  Bool isLoaded() { libRef.val != null }

  XetoLib? get(Bool checked := true)
  {
    lib := libRef.val as XetoLib
    if (lib != null) return lib
    if (checked) throw Err("Not loaded: $name")
    return null
  }

  Void set(XetoLib lib) { libRef.compareAndSet(null, lib) }

  private const AtomicRef libRef := AtomicRef()
}

