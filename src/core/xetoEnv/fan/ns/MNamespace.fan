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
using haystack::Grid
using haystack::UnknownLibErr
using haystack::UnknownSpecErr

**
** LibNamespace implementation base class
**
@Js
abstract const class MNamespace : LibNamespace
{
  new make(NameTable names, LibVersion[] versions)
  {
    // order versions by depends - also checks all internal constraints
    versions = LibVersion.orderByDepends(versions)

    // build list and map of entries
    list := MLibEntry[,]
    list.capacity = versions.size
    map := Str:MLibEntry[:]
    versions.each |x|
    {
      entry := MLibEntry(x)
      list.add(entry)
      map.add(x.name, entry)
    }

    this.names       = names
    this.entriesList = list
    this.entriesMap  = map
    this.sysLib      = lib("sys")
    this.sys         = MSys(sysLib)
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  const override NameTable names

//////////////////////////////////////////////////////////////////////////
// Libs
//////////////////////////////////////////////////////////////////////////

  const override Lib sysLib

  override LibVersion[] versions()
  {
    entriesList.map |x->LibVersion| { x.version }
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
    e := entry(name, false)
    if (e == null)
    {
      if (checked) throw UnknownLibErr(name)
      return null
    }
    if (e.isLoaded) return e.get
    return loaded(e, loadSync(e.version))
  }

  override Void libAsync(Str name, |Err?, Lib?| f)
  {
    e := entry(name, false)
    if (e == null) return f(UnknownLibErr(name), null)
    if (e.isLoaded) return f(null, e.get)
    loadAsync(e.version) |err, lib|
    {
      if (lib != null) lib = loaded(e, lib)
      f(err, lib)
    }
  }

  internal MLibEntry? entry(Str name, Bool checked := true)
  {
    entry := entriesMap.get(name) as MLibEntry
    if (entry != null) return entry
    if (checked) throw UnknownLibErr(name)
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Loading
//////////////////////////////////////////////////////////////////////////

  private Lib loaded(MLibEntry entry, XetoLib lib)
  {
    entry.set(lib)
    allLoaded.val = entriesList.all |x| { x.isLoaded }
    return entry.get
  }

  abstract XetoLib loadSync(LibVersion v)

  abstract Void loadAsync(LibVersion v, |Err?, XetoLib?| f)

//////////////////////////////////////////////////////////////////////////
// Lookups
//////////////////////////////////////////////////////////////////////////

  override XetoType? type(Str qname, Bool checked := true)
  {
    colon := qname.index("::") ?: throw ArgErr("Invalid qname: $qname")
    libName := qname[0..<colon]
    typeName := qname[colon+2..-1]
    type := lib(libName, false)?.type(typeName, false)
    if (type != null) return type
    if (checked) throw UnknownSpecErr("Unknown data type: $qname")
    return null
  }

  override XetoSpec? spec(Str qname, Bool checked := true)
  {
    colon := qname.index("::") ?: throw ArgErr("Invalid qname: $qname")

    libName := qname[0..<colon]
    names := qname[colon+2..-1].split('.', false)

    spec := lib(libName, false)?.spec(names.first, false)
    for (i:=1; spec != null && i<names.size; ++i)
      spec = spec.slot(names[i], false)

    if (spec != null) return spec
    if (checked) throw UnknownSpecErr(qname)
    return null
  }

  override Dict? instance(Str qname, Bool checked := true)
  {
    colon := qname.index("::") ?: throw ArgErr("Invalid qname: $qname")

    libName := qname[0..<colon]
    name := qname[colon+2..-1]

    instance := lib(libName, false)?.instance(name, false)

    if (instance != null) return instance
    if (checked) throw haystack::UnknownRecErr(qname)
    return null
  }

  override Spec? specOf(Obj? val, Bool checked := true)
  {
    if (val == null) return sys.none

    // dict handling
    dict := val as Dict
    if (dict != null)
    {
      specRef := dict["spec"] as Ref
      if (specRef == null) return sys.dict
      return spec(specRef.id, checked)
    }

    // look in Fantom class hiearchy
    type := val as Type ?: val.typeof
    for (Type? p := type; p != null; p = p.base)
    {
      spec := factories.typeToSpec(p)
      if (spec != null) return spec
      spec = p.mixins.eachWhile |m| { factories.typeToSpec(m) }
      if (spec != null) return spec
    }

    // fallbacks
    if (val is List) return sys.list
    if (type.fits(Grid#)) return lib("ph").type("Grid")

    // cannot map to spec
    if (checked) throw UnknownSpecErr("No spec mapped for '$type'")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const MSys sys
  const MFactories factories := MFactories()
  private const Str:MLibEntry entriesMap
  private const MLibEntry[] entriesList  // orderd by depends
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

  XetoLib? get() { libRef.val as XetoLib ?: throw Err("Not loaded: $name") }

  Void set(XetoLib lib) { libRef.compareAndSet(null, lib) }

  private const AtomicRef libRef := AtomicRef()
}

