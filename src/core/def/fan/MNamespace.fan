//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Nov 2018  Brian Frank  Creation
//

using concurrent
using haystack

**
** Namespace implementation base class
**
@NoDoc @Js
abstract const class MNamespace : Namespace
{

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Timestamp when created
  override const DateTime ts := DateTime.now(null)

  ** Timestamp key
  override const Str tsKey := ts.toLocale(Etc.tsKeyFormat)

  ** Debug string
  override final Str toStr() { "$typeof.name [$tsKey]" }

  ** Lazy loading support
  const MLazy lazy := MLazy(this)

//////////////////////////////////////////////////////////////////////////
// Iterators
//////////////////////////////////////////////////////////////////////////

  override final Def[] findDefs(|Def->Bool| f)
  {
    acc := Def[,]
    eachDef |def| { if (f(def)) acc.add(def) }
    return acc
  }

  override final Bool hasDefs(|Def->Bool| f)
  {
    eachWhileDef |def| { f(def) ? "break" : null } != null
  }

//////////////////////////////////////////////////////////////////////////
// Abstracts
//////////////////////////////////////////////////////////////////////////

  ** Cache of commonly used defs for quick access
  abstract MQuick quick()

//////////////////////////////////////////////////////////////////////////
// Fits
//////////////////////////////////////////////////////////////////////////

  override final Bool isFeature(Def def) { feature(def.name, false) != null }

  override final Bool fitsMarker(Def def) { fits(def, quick.marker) }
  override final Bool fitsVal(Def def)    { fits(def, quick.val) }
  override final Bool fitsChoice(Def def) { fits(def, quick.choice) }
  override final Bool fitsEntity(Def def) { fits(def, quick.entity) }

  override final Bool fits(Def def, Def parent)
  {
    inheritance(def).containsSame(parent)
  }

  override final Kind defToKind(Def def)
  {
    defs := inheritance(def)
    for (i := 0; i<defs.size; ++i)
    {
      kind := Kind.fromDefName(defs[i].name, false)
      if (kind != null) return kind
    }
    return Kind.obj
  }

//////////////////////////////////////////////////////////////////////////
// Reflection
//////////////////////////////////////////////////////////////////////////

  override Obj? declared(Def def, Str name)
  {
    val := def.get(name)
    if (val == null) return null
    inherited := supertypes(def).any |s| { s.get(name) == val }
    if (inherited) return null
    return val
  }

  override Def[] supertypes(Def def)
  {
    resolveList(def["is"])
  }

  override Def[] subtypes(Def def)
  {
    findDefs |x| { matchSubtype(def, x) }
  }

  override Bool hasSubtypes(Def def)
  {
    lazy.hasSubtypes(def)
  }

  internal Bool matchSubtype(Def def, Def x)
  {
    if (def === x) return false
    if (x.symbol.type.isKey) return false
    isSymbols := x["is"] as List
    if (isSymbols == null) return false
    return isSymbols.any { it == def.symbol }
  }

  override Def[] inheritance(Def def)
  {
    mdef := (MDef)def
    cached := mdef.inheritanceRef.val
    if (cached != null) return cached
    acc := Str:Def[:]
    acc.ordered = true
    doInheritance(acc, def)
    mdef.inheritanceRef.val = cached = acc.vals.toImmutable
    return cached
  }

  override Int inheritanceDepth(Def def)
  {
    n := 0
    Def? p := def
    while (true)
    {
      p = supertypes(p).first
      if (p == null) break
      n++
    }
    return n
  }

  private Void doInheritance(Str:Def acc, Def def)
  {
    key := def.symbol.toStr
    if (acc[key] != null) return
    if (def.symbol.type.isTerm) acc[key] = def
    supertypes(def).each |superkind| { doInheritance(acc, superkind) }
  }

  override Def[] tags(Def parent) { associations(parent, quick.tags) }

  override Def[] associations(Def parent, Def assoc) { lazy.associations(parent, assoc) }

  override Def[] choices(Def def) { lazy.choices(def) }

  override final Def? kindDef(Obj? val, Bool checked := true)
  {
    if (val != null)
    {
      kind := quick.fromFixedType(val.typeof)
      if (kind != null) return kind
      if (val is Dict) return quick.dict
      if (val is List) return quick.list
      if (val is Grid) return quick.grid
    }
    if (checked) throw NotHaystackErr("$val [${val?.typeof}]")
    return null

  }

  override final Def[] implement(Def def)
  {
    DefUtil.implement(this, def)
  }

  override final Reflection reflect(Dict subject)
  {
    MReflection.reflect(this, subject)
  }

  override final Dict proto(Dict parent, Dict proto)
  {
    MPrototyper(this, parent).generate(proto).first
  }

  override final Dict[] protos(Dict parent)
  {
    MPrototyper(this, parent).generate(null)
  }

//////////////////////////////////////////////////////////////////////////
// Symbol to Uri
//////////////////////////////////////////////////////////////////////////

  override final Uri symbolToUri(Str symbol)
  {
    def := def(symbol, false)

    // TODO
    if (def == null)
      return "http://localhost/def/dummy#$symbol".toUri

    base := def.lib.baseUri.toStr
    ver := def.lib.version.toStr
    size := base.size + 1 + ver.size + 1 + symbol.size
    return StrBuf(size)
           .add(base).add(ver).addChar('#')
           .add(symbol).toStr.toUri
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  override final Grid toGrid()
  {
    Etc.makeDictsGrid(null, defs.sort)
  }

  override final Void dump(OutStream out := Env.cur.out)
  {
    out.printLine("--- $toStr ---")
    defs.each |def|
    {
      out.printLine("$def is:" + def["is"])
    }
    out.flush
  }


  private Def[] resolveList(Obj? symbols)
  {
    if (symbols == null) return Def#.emptyList
    if (symbols is List)
      return ((List)symbols).map |symbol->Def| { resolve(symbol) }
    else
      return [resolve(symbols)]
  }

  private Def resolve(Symbol symbol) { def(symbol.toStr) }

  virtual Bool isSkySpark() { false }

}