//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jan 2026  Brian Frank  Creation
//

using util
using xeto
using haystack

const class ConvertUtil
{
   ** Find min indentation in block of code
   static Int indentation(Str src)
   {
    indent := -1
    src.splitLines.each |line|
    {
      if (line.trim.isEmpty) return
      lineIndent := 0
      while (lineIndent < line.size && line[lineIndent].isSpace) lineIndent++
      indent = indent < 0 ? lineIndent : indent.min(lineIndent)
    }
    return indent
  }

  ** Find min indentatation and move every line to the left that many spaces
  static Str removeIndentation(Str src)
  {
    indent := indentation(src)
    if (indent <= 0) return src
    return src.splitLines.map |s->Str|
    {
      if (s.trimToNull == null) return ""
      else return s[indent..-1]
    }.join("\n")
  }

  ** Try to deduce the xeto type for a param from a defcomp cell name and its meta. If we
  ** can't figure it out return 'Obj?'
  static AType cellToType(Str cellName, Dict meta)
  {
    // handle various rule binds
    if (meta.has("bind")) return AType("sys::Entity")
    else if (meta.has("bindAll")) return AType("sys::List")
    else if (meta.has("bindOut")) return AType("ph::Point")

    // special cell names
    _is := meta["is"] as Symbol
    switch (cellName)
    {
      case "target": return symbolToType(_is) ?: AType("sys::Entity")
      case "date":   return symbolToType(_is) ?: AType("sys::Date")
    }

    // final attempt is the raw conversion of is:^symbol
    return symbolToType(_is) ?: AType.obj
  }

  ** Map the symbol to a xeto type or return null.
  ** This is a pretty naive implementation.
  static AType? symbolToType(Symbol? s)
  {
    if (s == null) return null

    name := s.name
    switch (name)
    {
      case "bool":     return AType("sys::Bool")
      case "date":     return AType("sys::Date")
      case "dateTime": return AType("sys::DateTime")
      case "number":   return AType("sys::Number")
      case "str":      return AType("sys::Str")
      case "ref":      return AType("sys::Ref")
      case "dict":     return AType("sys::Dict")
      case "grid":     return AType("sys::Grid")
      default:         return null
    }
  }

  ** Map defcomp cell meta to swizzle from old rule engine to new rule enigne meta
  static Dict mapDefcompCellMeta(Dict meta)
  {
    acc   := Str:Obj[:]
    input := false
    meta.each |v, k|
    {
      // skip "is"
      if (k == "is") return

      // watch will be handled after we scan all other meta
      if (k == "watch") return

      // TODO: handle other Symbols?
      // if (v is Symbol) acc[k] = "Symbol ${((Symbol)v).name.toCode}"

      switch (k)
      {
        case "bind":
          acc["ruleBind"] = v
          input = true
        case "bindAll":
          acc["ruleBind"] = v
          acc["of"] = Ref("sys::Entity")
          input = true
        case "bindTuning":   acc["ruleBindTuning"] = v
        case "bindOut":      acc["ruleBind"] = v
        case "defVal":       acc["axon"] = Etc.toAxon(v)
        case "toCurVal":     acc["ruleToCurVal"] = Marker.val
        case "toWriteLevel": acc["ruleToWriteLevel"] = v
        default:             acc[k] = v
      }
    }

    // handle watch for inputs
    if (input && meta.missing("watch")) acc["ruleNoWatch"] = Marker.val

    return Etc.makeDict(acc)
  }

//////////////////////////////////////////////////////////////////////////
// Enum (copied from DefUtil)
//////////////////////////////////////////////////////////////////////////

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
}

