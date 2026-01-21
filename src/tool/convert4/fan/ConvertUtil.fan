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
    if (meta.has("bind")) return AType("Entity")
    else if (meta.has("bindAll")) return AType.map(List#)
    else if (meta.has("bindOut")) return AType("Point")

    // special cell names
    _is := meta["is"] as Symbol
    switch (cellName)
    {
      case "target": return symbolToType(_is) ?: AType("Entity")
      case "date":   return symbolToType(_is) ?: AType("Date")
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
      case "bool":     return AType.map(Bool#)
      case "date":     return AType.map(Date#)
      case "dateTime": return AType.map(DateTime#)
      case "number":   return AType.map(Number#)
      case "str":      return AType.map(Str#)
      case "ref":      return AType.map(Ref#)
      case "dict":     return AType.map(Dict#)
      case "grid":     return AType.map(Grid#)
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
        // TODO: should this be mapped to 'val' meta instead?
        case "defVal":       acc["axon"] = v
        case "toCurVal":     acc["ruleToCurVal"] = Marker.val
        case "toWriteLevel": acc["ruleToWriteLevel"] = v
        default:             acc[k] = v
      }
    }

    // handle watch for inputs
    if (input && meta.missing("watch")) acc["ruleNoWatch"] = Marker.val

    return Etc.makeDict(acc)
  }
}

