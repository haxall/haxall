//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Nov 2017  Brian Frank  Creation
//

using xeto
using haystack

**
** Utilities
**
@Js
class DefUtil
{

  **
  ** Convenience for parseEnum which returns only a list of
  ** string names.  Using this method is more efficient than
  ** calling parseEnums and then mapping the keys.
  **
  static Str[] parseEnumNames(Obj? enum)
  {
    if (enum == null) return Str#.emptyList
    if (enum is Str && !enum.toStr.startsWith("-")) return parseEnumSplitNames(enum)
    return parseEnum(enum).keys
  }

  **
  ** Parse enum as ordered map of Str:Dict keyed by name.  Dict tags:
  **   - name: str key
  **   - doc: fandoc string if available
  **
  ** Supported inputs:
  **   - null returns empty list
  **   - Dict of Dicts
  **   - Str[] names
  **   - Str newline separated names
  **   - Str comma separated names
  **   - Str fandoc list as - name: fandoc lines
  **
  static Str:Dict parseEnum(Obj? enum)
  {
    if (enum == null) return emptyEnum

    if (enum is Dict) return parseEnumDict(enum)

    if (enum is List) return parseEnumList(enum)

    // Xeto allows enum spec ref; for now just support predefined ph enums
    if (enum is Ref)
    {
      switch (enum.toStr)
      {
        case "ph::WeatherCondEnum":     return parseEnum("unknown,clear,partlyCloudy,cloudy,showers,rain,thunderstorms,ice,flurries,snow")
        case "ph::WeatherDaytimeEnum":  return parseEnum("nighttime,daytime")
        case "ph.points::RunEnum":      return parseEnum("off,on")
        case "ph.points::OccupiedEnum": return parseEnum("unoccupied occupied")
      }
      echo("WARN: xeto enum refs not supported yet: $enum")
      return emptyEnum
    }

    enumStr := enum.toStr.trimStart
    if (enumStr.startsWith("-")) return parseEnumFandoc(enumStr)
    return parseEnumSplit(enumStr)
  }

  private static const Str:Dict emptyEnum := Str:Dict[:]

  private static Str:Dict parseEnumDict(Dict dict)
  {
    if (dict.isEmpty) return emptyEnum
    acc := Str:Dict[:] { ordered = true }
    dict.each |meta, key| { acc.add(key, Etc.dictSet(meta, "name", key)) }
    return acc
  }

  private static Str:Dict parseEnumList(Str[] list)
  {
    if (list.isEmpty) return emptyEnum
    acc := Str:Dict[:] { ordered = true }
    list.each |key| { acc.add(key, Etc.dict1("name", key)) }
    return acc
  }

  private static Str:Dict parseEnumFandoc(Str enum)
  {
    acc := Str:Dict[:] { ordered = true }
    key := ""
    doc := ""
    enum.splitLines.each |line|
    {
      line = line.trim
      if (line.isEmpty) return
      if (line.startsWith("-"))
      {
        colon := line.index(":")
        if (colon == null) throw Err("Expecting '-key: doc', not: $line")
        key = line[1..<colon].trim
        doc = line[colon+1..-1].trim
      }
      else
      {
        doc = doc + "\n" + line
      }
      acc[key] = Etc.dict2("name", key, "doc", doc)
    }
    return acc
  }

  private static Str:Dict parseEnumSplit(Str enum)
  {
    acc := Str:Dict[:] { ordered = true }
    keys := enum.splitLines
    if (keys.size == 1) keys = enum.split(',')
    keys.each |key| { acc.add(key, Etc.dict1("name", key)) }
    return acc
  }

  private static Str[] parseEnumSplitNames(Str enum)
  {
    keys := enum.splitLines
    if (keys.size == 1) keys = enum.split(',')
    return keys
  }

//////////////////////////////////////////////////////////////////////////
// Reflection
//////////////////////////////////////////////////////////////////////////

  ** Iterate each tag def in given term
  static Void eachTag(DefNamespace ns, Def term, |Def| f)
  {
    if (term.symbol.type.isConjunct)
    {
      term.symbol.eachPart |name|
      {
        tag := ns.def(name, false)
        if (tag != null) f(tag)
      }
    }
    else
    {
      f(term)
    }
  }

  ** Tags to add to implement given def
  static Def[] implement(DefNamespace ns, Def def)
  {
    // add myself
    acc := Str:Def[:] { ordered = true }
    eachTag(ns, def) |tag| { acc[tag.name] = tag }

    // handle any mandatory markers in my inheritance hierarchy
    ns.inheritance(def).each |supertype|
    {
      if (supertype.has("mandatory"))
        eachTag(ns, supertype) |tag| { acc[tag.name] = tag }
    }
    return acc.vals
  }

  ** Union of reflections
  static Def[] union(Reflection[] reflects)
  {
    if (reflects.isEmpty) return Def#.emptyList
    if (reflects.size == 1) return reflects[0].defs
    acc := Symbol:Def[:]
    reflects.each |reflect|
    {
      reflect.defs.each |def| { acc[def.symbol] = def }
    }
    return acc.vals
  }

  ** Intersection of reflections
  static Def[] intersection(Reflection[] reflects)
  {
    if (reflects.isEmpty) return Def#.emptyList
    if (reflects.size == 1) return reflects[0].defs
    return reflects[0].defs.findAll |def|
    {
      reflects.all |r| { r.def(def.symbol.toStr, false) != null }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Accumulate
//////////////////////////////////////////////////////////////////////////

  ** Implement standard 'accumulate' inheritance behavior
  static Obj accumulate(Obj a, Obj b)
  {
    acc := DefAccItem[,]

    if (a is List)
      ((List)a).each |x| { doAccumulate(acc, x) }
    else
      doAccumulate(acc, a)

    if (b is List)
      ((List)b).each |x| { doAccumulate(acc, x) }
    else
      doAccumulate(acc, b)

    return acc.sort.map |x| { x.val }
  }

  private static Void doAccumulate(DefAccItem[] acc, Obj val)
  {
    item := DefAccItem(val)
    if (!acc.contains(item))
      acc.add(item)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Return if a given tag def is a password of password subtype
  static Bool isPassword(Def def)
  {
    if (def.symbol.name == "password") return true
    supers := def["is"] as List
    return supers != null && supers.any |s| { s.toStr == "password" }
  }

  ** Given a list of atomic marker tags, expand to include valid
  ** conjunct combinations.  The result is sorted by most parts to
  ** least parts.
  static Def[] expandMarkersToConjuncts(MNamespace ns, Def[] markers)
  {
    // map list of defs to a Dict instance of those markers
    acc := Str:Obj[:]
    markers.each |m| { acc[m.name] = Marker.val }
    dict := Etc.makeDict(acc)

    // find matching conjuncts
    matches := ns.lazy.conjuncts.findAll |c| { c.symbol.hasTerm(dict) }
    if (matches.isEmpty) return markers
    return matches.addAll(markers)
  }

  ** Map terms (which might include conjuncts) into marker tag names
  static Str[] termsToTags(Def[] terms)
  {
    if (terms.isEmpty) return Str#.emptyList
    acc := Str:Str[:] { ordered = true }
    terms.each |term|
    {
      if (term.symbol.type.isTag)
        acc[term.name] = term.name
      else
        term.symbol.eachPart |tag| { acc[tag] = tag }
    }
    return acc.vals
  }

  ** The unique base types in the given def list.  Any defs which have
  ** one of their supertypes in the list are excluded. For example given
  ** a list of 'equip,ahu,vav' return just 'equip'
  static Def[] findBaseDefs(DefNamespace ns, Def[] defs)
  {
    bySymbol := Str:Def[:].setList(defs) { it.symbol.toStr }
    return defs.exclude |def|
    {
      ns.inheritance(def).any |x| { x !== def && bySymbol[x.symbol.toStr] != null }
    }
  }

  ** Resolve a single Symbol/Str to a Def or return null if any error
  static Def? resolve(DefNamespace ns, Obj? val)
  {
    if (val == null) return null
    return ns.def(val.toStr, false)
  }

  ** Resolve list of Symbol/Str keys to Def[].  Silently ignore errors.
  static Def[] resolveList(DefNamespace ns, Obj? val)
  {
    if (val == null) return Def#.emptyList
    acc := Def[,]
    if (val isnot List) val = [val]
    ((List)val).each |item|
    {
      def := ns.def(item.toStr, false)
      if (def != null) acc.add(def)
    }
    return acc
  }
}

**************************************************************************
** DefAccItem
**************************************************************************

** Wrapper to accumulate Dicts safely
@Js internal class DefAccItem
{
  new make(Obj val)
  {
    this.key = val is Dict ? ZincWriter.valToStr(val) : val
    this.val = val
  }

  override Bool equals(Obj? that) { key == ((DefAccItem)that).key }

  override Int compare(Obj that) { key <=> ((DefAccItem)that).key }

  Obj key
  Obj val
}

