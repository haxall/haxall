//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2019  Brian Frank  Creation
//

using concurrent
using haystack

**
** MOverlayLib is used with MOverlayNamespace to overlay the project
** specific defs over the installed defs.
**
@NoDoc @Js
const class MOverlayLib : MLib
{
  new make(BOverlayLib b) : super(BDef(b.symbol, b.libRef, b.meta))
  {
    b.libRef.val = this

    b.defs.add(this)
    b.defsMap.add(this.symbol.toStr, this)

    this.defs = b.defs
    this.defsMap = b.defsMap
  }

  const Def[] defs

  Def? def(Str symbol, Bool checked := true)
  {
    def := defsMap[symbol]
    if (def != null) return def
    if (checked) throw UnknownDefErr(symbol.toStr)
    return null
  }

  Bool hasDef(Str symbol) { defsMap[symbol] != null }

  Void eachDef(|Def| f) { defsMap.each(f) }

  private const Str:Def defsMap
}

**************************************************************************
** BOverlayLib
**************************************************************************

** BOverlayLib is used to build a MOverlayLib
@NoDoc @Js
class BOverlayLib
{
  new make(Namespace base, Dict meta)
  {
    // verify "lib:foo" key
    symbol := (Symbol)meta->def
    if (!symbol.type.isKey || symbol.part(0) != "lib")
      throw ArgErr(symbol.toStr)

    this.base = base
    this.symbol = symbol
    this.meta = meta
  }

  Bool isDup(Str symbol) { defsMap[symbol] != null }

  Void addDef(Dict meta)
  {
    def := toDef(meta)
    defsMap.add(def.symbol.toStr, def)
    defs.add(def)
  }

  private MDef toDef(Dict meta)
  {
    // apply inheritance if necessary
    meta = inherit(meta)

    // builder stub
    symbol := (Symbol)meta->def
    b := BDef(symbol, libRef, meta)

    // check if a feature key like "foo:bar"
    if (symbol.type.isKey) return toKey(b)

    // fallback to MDef
    return toFallback(b)
  }

  private Dict inherit(Dict meta)
  {
    // we only apply inheritance when def has explicit 'is' tag
    supertypes := Symbol.toList(meta["is"])
    if (supertypes.isEmpty) return meta

    // inherit from each supertype
    acc := Etc.dictToMap(meta)
    supertypes.each |supertype|
    {
      inheritFrom(acc, base.def(supertype.toStr, false))
    }
    return Etc.makeDict(acc)
  }

  private Void inheritFrom(Str:Obj? acc, Def? supertype)
  {
    if (supertype == null) return
    supertype.each |v, n|
    {
      tag := base.def(n, false)
      if (tag == null) return
      cur := acc[n]
      if (cur == null)
      {
        if (tag.missing("noInherit")) acc[n] = v
      }
      else
      {
        if (tag.has("accumulate")) acc[n] = DefUtil.accumulate(cur, v)
      }
    }
  }

  private MDef toKey(BDef b)
  {
    feature := toFeature(b.symbol.part(0))
    def := feature.createDef(b)
    return def
  }

  private MFeature toFeature(Str name)
  {
    base.feature(name)
  }

  private MDef toFallback(BDef b)
  {
    return MDef(b)
  }

  internal const Namespace base
  internal const Symbol symbol
  internal const Dict meta
  internal const AtomicRef libRef := AtomicRef()
  internal Def[] defs := [,]
  internal Str:Def defsMap := [:]
}