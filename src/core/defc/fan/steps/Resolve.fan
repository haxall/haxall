//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jul 2018  Brian Frank  Creation
//    9 Jan 2019  Brian Frank  Redesign
//

using xeto
using haystack

**
** Resolve all symbols to their defs
**
internal class Resolve : DefCompilerStep
{
  new make(DefCompiler c) : super(c) {}

  override Void run()
  {
    eachLib |lib| { resolveLib(lib) }
  }

  private Void resolveLib(CLib lib)
  {
    // resolve dependencies
    includes := resolveDepends(lib)

    // build map of all symbols in this lib's scope
    acc := Str:CDef[:]
    includes.each |include| { resolveScope(lib, acc, include) }
    resolveScope(lib, acc, lib)

    // now resolve all refs within the defs/defsx
    scope := ResolveScope(lib, acc)
    lib.defs.each |def| { resolveDef(scope, def) }
    lib.defXs.each |defx| { resolveDefX(scope, defx) }
    lib.scope = scope
  }

  private CLib[] resolveDepends(CLib lib)
  {
    acc := CLib[,]
    lib.depends.each |symbol|
    {
      depend := compiler.libs[symbol]
      if (depend == null) err("Depend not found: $symbol", lib.loc)
      else acc.add(depend)
    }
    return acc
  }

  private Void resolveScope(CLib lib, Str:CDef scope, CLib include)
  {
    include.defs.each |def|
    {
      symbol := def.symbol.toStr
      dup := scope[symbol]
      if (dup != null) err("Duplicate symbols in lib scope: $symbol [$dup.lib.name, $include.name]", lib.loc)
      scope[symbol] = def
    }
  }

  private Void resolveDef(ResolveScope scope, CDef def)
  {
    resolveSymbolParts(scope, def)
    def.meta = resolveDeclaredToMeta(scope, def.declared, def.loc)
  }

  private Void resolveDefX(ResolveScope scope, CDefX defx)
  {
    defx.meta = resolveDeclaredToMeta(scope, defx.declared, defx.loc)
  }

//////////////////////////////////////////////////////////////////////////
// Parts
//////////////////////////////////////////////////////////////////////////

  private Void resolveSymbolParts(ResolveScope scope, CDef def)
  {
    switch (def.symbol.type)
    {
      case SymbolType.tag:      return
      case SymbolType.key:      resolveKeyParts(scope, def)
      case SymbolType.conjunct: resolveConjunctParts(scope, def)
    }

    // if we can't resolve the parts correctly, then
    // consider this a fatal error for this particular def
    if (def.parts == null) def.fault = true
  }

  private Void resolveKeyParts(ResolveScope scope, CDef def)
  {
    // for keys we only resolve feature part
    featureSymbol := def.symbol.parts.first
    feature := scope.get(featureSymbol)
    if (feature == null) return err("Unresolved feature key part: $featureSymbol", def.loc)
    def.parts = CKeyParts(def, feature)
  }

  private Void resolveConjunctParts(ResolveScope scope, CDef def)
  {
    // resolve each part
    tags := CDef[,]
    tags.capacity = def.symbol.parts.size
    def.symbol.parts.each |tagSymbol|
    {
      tag := scope.get(tagSymbol)
      if (tag == null) return err("Unresolved conjunct part: $tagSymbol", def.loc)
      tags.add(tag)
    }

    // simple conjuct
    def.parts = CConjunctParts(def, tags)
  }

//////////////////////////////////////////////////////////////////////////
// Declared Values
//////////////////////////////////////////////////////////////////////////

  internal Str:CPair resolveDeclaredToMeta(ResolveScope scope, Dict declared, CLoc loc)
  {
    acc := Str:CPair[:]
    declared.each |v, n|
    {
      tag := resolveTag(scope, n, loc)
      val := resolveVal(scope, n, v, loc) ?: v
      acc[n] = CPair(n, tag, val)
    }
    return acc
  }

  private CDef? resolveTag(ResolveScope scope, Str name, CLoc loc)
  {
    try
    {
      symbol := compiler.symbols.parse(name)

      def := scope[symbol]
      if (def != null) return def

      if (reportUnresolvedTag(name)) err("Unresolved tag symbol: $name", loc)

      return null
    }
    catch (Err e)
    {
      err("Invalid tag $name: $e.msg", loc)
      return null
    }
  }

  private Bool reportUnresolvedTag(Str name)
  {
    // don't report meta with underbar for backward
    // compatibility with old style param meta for actions
    if (name.contains("_")) return false

    // allow these tags to be used for ph* libs
    if (name == "icon") return false
    if (name == "sysMod") return false
    if (name == "defVal") return false

    return true
  }

  private Obj? resolveVal(ResolveScope scope, Str name, Obj? val, CLoc loc)
  {
    if (val == null) return null
    if (name == "is") return resolveIsVal(scope, val, loc)
    if (val is List) return resolveListVal(scope, name, val, loc)
    if (val is Symbol) return resolveSymbolVal(scope, name, val, loc)
    return val
  }

  private Obj?[] resolveListVal(ResolveScope scope, Str name, Obj?[] list, CLoc loc)
  {
    if (name == "depends") return list // special case
    acc := Obj?[,]
    acc.capacity = list.size
    list.each |v|
    {
      v = resolveVal(scope, name, v, loc)
      if (v != null) acc.add(v)
    }
    return acc
  }

  private CDef[] resolveIsVal(ResolveScope scope, Obj val, CLoc loc)
  {
    List list := val as List ?: [val]
    acc := CDef[,]
    acc.capacity = list.size
    list.each |item|
    {
      if (item isnot Symbol) return err("Expecting symbol for 'is' tag: $item", loc)
      def := resolveSymbolVal(scope, "is", item, loc)
      if (def != null) acc.add(def)
    }
    return acc
  }

  private CDef? resolveSymbolVal(ResolveScope scope, Str name, Symbol val, CLoc loc)
  {
    try
    {
      symbol := compiler.symbols.parse(val.toStr)

      def := scope[symbol]
      if (def != null) return def

      err("Unresolved symbol $name=$symbol", loc)

      return null
    }
    catch (Err e)
    {
      err("Invalid symbol $name=$val: $e.msg", loc)
      return null
    }
  }
}

**************************************************************************
** ResolveScope
**************************************************************************

internal class ResolveScope
{
  new make(CLib lib, Str:CDef map) { this.lib = lib; this.map = map }

  @Operator CDef? get(CSymbol symbol) { map.get(symbol.toStr) }

  CLib lib
  Str:CDef map
  Str:CDef[] refTerms := [:]
}

