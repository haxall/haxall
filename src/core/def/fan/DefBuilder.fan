//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Nov 2018  Brian Frank  Creation
//

using concurrent
using xeto
using haystack

**
** DefBuilder is used to build up the Def and DefNamespace instances.
** This API does **not** perform validation or error checking.
**
@NoDoc @Js
class DefBuilder
{

//////////////////////////////////////////////////////////////////////////
// Add
//////////////////////////////////////////////////////////////////////////

  ** Pluggable factory
  DefFactory factory := DefFactory()

  ** Add new def with normalized meta
  Void addDef(Dict meta, Obj? aux := null)
  {
    lib := toLib(meta)
    def := toDef(lib, meta, aux)
    defs.add(def.symbol.toStr, def)
  }

  ** Get or lazily create BLib
  private BLib toLib(Dict meta)
  {
    libName := meta->lib.toStr
    lib := libs[libName]
    if (lib == null) libs[libName] = lib = BLib(libName)
    return lib
  }

  ** Create MDef implementation
  private MDef toDef(BLib lib, Dict meta, Obj? aux)
  {
    // builder stub
    symbol := (Symbol)meta->def
    b := BDef(symbol, lib.ref, meta, aux)

    // check if a feature key like "lib:ph"
    if (symbol.type.isKey) return toKey(b)

    // check if we need define feature
    if ((meta["is"] as List)?.first?.toStr == "feature")
      toFeature(symbol.toStr)

    // fallback to MDef
    return toFallback(b)
  }

  private MDef toKey(BDef b)
  {
    feature := toFeature(b.symbol.part(0))
    def := feature.createDef(b)
    if (feature.isFiletype) addFiletype(def)
    return def
  }

  private Void addFiletype(MFiletype def)
  {
    name := def.name
    filetypes.add(def)
    filetypesMap.add(name, def)
    filetypesMap.add(def.mimeType.toStr, def)
    filetypesMap.add("application/vnd.haystack+${name}", def)
  }

  private MFeature toFeature(Str name)
  {
    feature := features[name]
    if (feature == null)
    {
      features[name] = feature = factory.createFeature(BFeature(name, nsRef))
    }
    return feature
  }

  private MDef toFallback(BDef b)
  {
    return MDef(b)
  }

//////////////////////////////////////////////////////////////////////////
// Build
//////////////////////////////////////////////////////////////////////////

  ** Build into a def namespace
  DefNamespace build()
  {
    // walk thru all libs and assign MLib ref
    libsMap := Str:DefLib[:]
    libsList := DefLib[,]
    this.libs.each |blib|
    {
      // get def by name
      MLib mlib := defs.getChecked(blib.symbol)

      // assign to AtomicRef used by lib's defs
      blib.ref.val = mlib

      // add to indexing data structures
      libsList.add(mlib)
      libsMap[mlib.name] = mlib
    }

    // assign lib index
    libsList.sort
    libsList.each |MLib lib, i| { lib.indexRef.val = i }

    // initialize namespace builder stub
    b := BNamespace()
    b.ref = nsRef
    b.defsMap = defs
    b.features = features.vals.sort
    b.featuresMap = features
    b.libs = libsList
    b.libsMap = libsMap
    b.filetypes = filetypes.sort
    b.filetypesMap = filetypesMap

    // construct
    return factory.createNamespace(b)
  }

//////////////////////////////////////////////////////////////////////////
// Field
//////////////////////////////////////////////////////////////////////////

  private Str:Def defs := [:]
  private Str:BLib libs := [:]
  private Str:MFeature features := [:]
  private Filetype[] filetypes := [,]
  private Str:Filetype filetypesMap := [:]
  private AtomicRef nsRef := AtomicRef()
}

**************************************************************************
** BNamespace
**************************************************************************

** Builder namespace stub
@NoDoc @Js
class BNamespace
{
  AtomicRef? ref
  [Str:Def]? defsMap
  Feature[]? features
  [Str:Feature]? featuresMap
  DefLib[]? libs
  [Str:DefLib]? libsMap
  Filetype[]? filetypes
  [Str:Filetype]? filetypesMap
}

**************************************************************************
** BLib
**************************************************************************

** Builder lib def stub
@NoDoc @Js
internal class BLib
{
  internal new make(Str symbol)
  {
    this.symbol = symbol
    this.ref = AtomicRef()
  }

  internal const Str symbol
  internal const AtomicRef ref
  internal MDef[] defs := [,]
}

**************************************************************************
** BDef
**************************************************************************

** Builder def data to pass thru constructors
@NoDoc @Js
class BDef
{
  new make(Symbol symbol, AtomicRef libRef, Dict meta, Obj? aux := null)
  {
    this.symbol = symbol
    this.libRef = libRef
    this.meta   = meta
    this.aux    = aux
  }

  const Symbol symbol
  const Dict meta
  const AtomicRef libRef
  const Obj? aux
}

**************************************************************************
** BFeature
**************************************************************************

** Builder feature stub
@NoDoc @Js
class BFeature
{
  internal new make(Str name, AtomicRef nsRef)
  {
    this.name  = name
    this.nsRef = nsRef
  }

  const Str name
  internal AtomicRef nsRef
}

