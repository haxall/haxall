//
// Copyright (c) 2013, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 May 2014  Brian Frank  Creation
//

using util
using xeto

**
** Read Haystack data in [JSON]`docHaystack::Json` format.
**
@Js
class JsonReader : GridReader
{

  ** Wrap input stream. By default, the reader decodes JSON in the Haystack 4 (Hayson)
  ** format. Use the 'v3' option to decode JSON in the Haystack 3 format.
  **
  ** The following opts are supported:
  **  - 'v3' (Marker): read JSON encoded in the Haystack 3 format
  **
  **   g := JsonReader(in).readGrid
  **
  **   val := JsonReader(in, Etc.makeDict(["v3":Marker.val])).readVal
  new make(InStream in, Dict? opts := null)
  {
    this.in = JsonInStream(in)
    this.opts = opts ?: Etc.dict0
  }

  ** Read a value and auto close stream
  Obj? readVal(Bool close := true)
  {
    try
    {
      if (JsonParser.isV3(opts)) return JsonV3Parser(opts).parseVal(in.readJson)
      return HaysonParser(opts).parseVal(in.readJson)
    }
    finally
    {
      if (close) in.close
    }
  }

  ** Convenience for `readVal` as Grid
  override Grid readGrid() { readVal }

  private JsonInStream in
  Dict opts { private set }
}

**************************************************************************
** JsonParser
**************************************************************************

@NoDoc @Js
abstract class JsonParser
{
  static Bool isV3(Dict opts) { opts.has("v3") }

  new make(Dict opts) { this.opts = opts }

  Dict opts { private set }

  Bool notHaystack() { opts.has("notHaystack") }
  Bool safeNames() { opts.has("safeNames") }
  Bool safeVals() { opts.has("safeVals") }
}
**************************************************************************
** HaysonParser
**************************************************************************

** HaysonParser normalizes JSON values to Haystack values
@NoDoc @Js
class HaysonParser : JsonParser
{
  new make(Dict opts) : super(opts) { }

  Obj? parseVal(Obj? json)
  {
    if (json == null)  return null
    if (json is Str)   return json
    if (json is Map)   return parseMap(json)
    if (json is Float) return Number.make(json)
    if (json is Int)   return Number.makeInt(json)
    if (json is Bool)  return json
    if (json is List)  return parseList(json)
    throw Err("Unsupported JSON type: ${json.typeof.name}")
  }

  private Obj? parseMap(Str:Obj? json)
  {
    kind := json.remove("_kind")
    if (kind == null || kind == "dict") return parseDict(json)
    if (kind == "grid")     return parseGrid(json)
    if (kind == "number")   return parseNumber(json)
    if (kind == "marker")   return Marker.val
    if (kind == "ref")      return Ref.make(json["val"], json["dis"])
    if (kind == "date")     return Date.fromStr(json["val"])
    if (kind == "time")     return Time.fromStr(json["val"])
    if (kind == "dateTime") return parseDateTime(json)
    if (kind == "uri")      return Uri.fromStr(json["val"])
    if (kind == "symbol")   return Symbol.fromStr(json["val"])
    if (kind == "coord")    return Coord.make(json["lat"], json["lng"])
    if (kind == "remove")   return None.val
    if (kind == "na")       return NA.val
    if (kind == "xstr")     return XStr.decode(json["type"], json["val"])
    throw ParseErr("${json}")
  }

  private Grid parseGrid(Str:Obj? json)
  {
    gb := GridBuilder()
    parseGridMeta(gb, json)
    parseGridCols(gb, json)
    parseGridRows(gb, json)
    return gb.toGrid
  }

  private Void parseGridMeta(GridBuilder gb, Str:Obj? json)
  {
    obj := json["meta"]
    if (obj == null)   throw ParseErr("JSON root missing 'meta' field")
    if (obj isnot Map) throw ParseErr("JSON 'meta' must be Object map, not $obj.typeof.name")
    map := (Str:Obj?)obj
    ver := map["ver"]
    if (ver != "2.0" && ver != "3.0") throw ParseErr("Unsupported JSON 'meta.ver': $ver")
    map.remove("ver")
    gb.setMeta(parseDict(map))
  }

  private Void parseGridCols(GridBuilder gb, Str:Obj? json)
  {
    colsObj := json["cols"]
    if (colsObj == null) return
    if (colsObj isnot List) throw ParseErr("JSON 'cols' must be Array, not $colsObj.typeof.name")

    colsList := (Obj?[])colsObj
    colsList.each |colObj,i |
    {
      if (colObj isnot Map) throw ParseErr("JSON col $i must be Object map, not $colObj.typeof.name")
      colMap := (Str:Obj?)colObj

      name := colMap["name"]
      if (name == null) throw ParseErr("JSON col $i missing 'name' field: $colMap")

      metaObj := colMap["meta"]
      if (metaObj == null) return gb.addCol(name)

      if (metaObj isnot Map) throw ParseErr("JSON col $i meta must be Object map, not $metaObj.typeof.name")
      metaMap := (Str:Obj?)metaObj
      gb.addCol(name, parseDict(metaMap))
    }
  }

  private Void parseGridRows(GridBuilder gb, Str:Obj? json)
  {
    rowsObj := json["rows"]
    if (rowsObj == null) return
    if (rowsObj isnot List) throw ParseErr("JSON 'rows' must be Array, not $rowsObj.typeof.name")

    rowsList := (Obj?[])rowsObj
    rowsList.each |rowObj, i|
    {
      if (rowObj isnot Map) throw ParseErr("JSON row $i must be Object map, not $rowObj.typeof.name")
      rowMap := (Str:Obj?)rowObj

      cells := Obj?[,]
      cells.size = gb.numCols

      rowMap.each |v, n|
      {
        cells[gb.colNameToIndex(n)] = parseVal(v)
      }

      gb.addRow(cells)
    }
  }

  private Dict parseDict(Str:Obj? json)
  {
    if (json.isEmpty) return Etc.dict0
    acc := Str:Obj?[:]
    json.each |v, n|
    {
      if (v == null) return
      if (safeNames) n = Etc.toTagName(n)
      acc[n] = parseVal(v)
    }
    return Etc.makeDict(acc)
  }

  private List parseList(Obj?[] json)
  {
    Kind.toInferredList(json.map |x| { parseVal(x) })
  }

  private Number parseNumber(Str:Obj? json)
  {
    Obj? val  := json["val"]
    if (val is Str) val = ((Str)val).toFloat
    else            val = ((Num)val).toFloat
    Obj? unit := json["unit"] as Str
    if (unit != null) unit = Number.loadUnit(unit)
    return Number.make(val, unit)
  }

  private DateTime parseDateTime(Str:Obj? json)
  {
    tz := HaysonWriter.gmt
    if (json.containsKey("tz")) tz = TimeZone.fromStr(json["tz"])
    return DateTime.fromIso(json["val"]).toTimeZone(tz)
  }
}
**************************************************************************
** JsonV3Parser
**************************************************************************

** JsonV3Parser normalizes JSON values to Haystack values
@NoDoc @Js
class JsonV3Parser : JsonParser
{
  new make(Dict opts) : super(opts) { }

  Obj? parseVal(Obj? json)
  {
    if (json == null)  return null
    if (json is Str)   return parseStr(json)
    if (json is Map)   return parseMap(json)
    if (json is Float) return Number.make(json)
    if (json is Int)   return Number.makeInt(json)
    if (json is Bool)  return json
    if (json is List)  return parseList(json)
    throw Err("Unsupported JSON type: $json.typeof.name")
  }

  private Obj? parseMap(Str:Obj? json)
  {
    if (json["meta"] != null && json["cols"] != null && json["rows"] != null)
      return parseGrid(json)
    else
      return parseDict(json)
   }

  private Grid parseGrid(Str:Obj? json)
  {
    gb := GridBuilder()
    parseGridMeta(gb, json)
    parseGridCols(gb, json)
    parseGridRows(gb, json)
    return gb.toGrid
  }

  private Void parseGridMeta(GridBuilder gb, Str:Obj? json)
  {
    obj := json["meta"]
    if (obj == null) throw Err("JSON root missing 'meta' field")
    if (obj isnot Map) throw Err("JSON 'meta' must be Object map, not $obj.typeof.name")
    map := (Str:Obj?)obj
    ver := map["ver"]
    if (ver != "2.0" && ver != "3.0") throw Err("Unsupported JSON 'meta.ver': $ver != 3.0")
    map.remove("ver")
    gb.setMeta(parseDict(map))
  }

  private Void parseGridCols(GridBuilder gb, Str:Obj? json)
  {
    colsObj := json["cols"]
    if (colsObj == null) throw Err("JSON root missing 'cols' field")
    if (colsObj isnot List) throw Err("JSON 'cols' must be Array, not $colsObj.typeof.name")

    colsList := (Obj?[])colsObj
    colsList.each |colObj|
    {
      if (colObj isnot Map) throw Err("JSON col must be Object map, not $colObj.typeof.name")
      colMap := (Str:Obj?)colObj

      name := colMap["name"] as Str
      if (name == null) throw Err("JSON col missing 'name' field")
      colMap.remove("name")

      meta := parseDict(colMap)
      gb.addCol(name, meta)
    }
  }

  private Void parseGridRows(GridBuilder gb, Str:Obj? json)
  {
    rowsObj := json["rows"]
    if (rowsObj == null) throw Err("JSON root missing 'rows' field")
    if (rowsObj isnot List) throw Err("JSON 'rows' must be Array, not $rowsObj.typeof.name")

    rowsList := (Obj?[])rowsObj
    rowsList.each |rowObj|
    {
      if (rowObj isnot Map) throw Err("JSON row must be Object map, not $rowObj.typeof.name")
      rowMap := (Str:Obj?)rowObj

      cells := Obj?[,]
      cells.size = gb.numCols

      rowMap.each |v, n|
      {
        cells[gb.colNameToIndex(n)] = parseVal(v)
      }

      gb.addRow(cells)
    }
  }

  private Dict parseDict(Str:Obj? json)
  {
    if (json.isEmpty) return Etc.dict0
    acc := Str:Obj?[:]
    json.each |v, n|
    {
      if (v == null) return
      if (safeNames) n = Etc.toTagName(n)
      acc[n] = parseVal(v)
    }
    return Etc.makeDict(acc)
  }

  private Obj? parseList(Obj?[] json)
  {
    Kind.toInferredList(json.map |x| { parseVal(x) })
  }

  private Obj? parseStr(Str s)
  {
    if (s.size < 2 || s[1] != ':' || notHaystack) return s

    try
    {
      switch (s[0])
      {
        case 'm': return parseSingleton(s, Marker.val)
        case '-': return parseSingleton(s, None.val)
        case 'z': return parseSingleton(s, NA.val)
        case 'n': return parseNumber(s)
        case 'r': return parseRef(s)
        case 'y': return Symbol.fromStr(s[2..-1])
        case 'd': return Date.fromStr(s[2..-1])
        case 'h': return parseTime(s[2..-1])
        case 't': return parseDateTime(s[2..-1])
        case 's': return s[2..-1]
        case 'u': return Uri.fromStr(s[2..-1])
        case 'b': return Bin(s[2..-1])
        case 'c': return Coord.fromStr("C(" + s[2..-1] + ")")
        case 'x': c := s.index(":", 3) ?: throw Err("Invalid XStr: $s"); return XStr.decode(s[2..<c], s[c+1..-1])
        default:  throw Err("Unsupported type code: $s")
      }
    }
    catch (Err e)
    {
      if (safeVals) return s
      throw IOErr("Invalid Haystack string: $s [$e]")
    }
  }

  private Obj parseSingleton(Str s, Obj val)
  {
    if (s.size != 2) throw ParseErr("Invalid $val.typeof.name: $s")
    return val
  }

  private Number parseNumber(Str s)
  {
    space := s.index(" ")
    if (space == null) return Number(parseFloat(s[2..-1]))
    return Number(parseFloat(s[2..<space]), Number.loadUnit(s[space+1..-1]))
  }

  private Float parseFloat(Str s)
  {
    if (s.contains("_")) s = s.replace("_", "")
    if (s.startsWith("0x")) return Int.fromStr(s[2..-1], 16).toFloat
    return s.toFloat
  }

  private Time parseTime(Str s)
  {
    if (s[1] == ':') s = "0" + s
    if (s.size == 5) s = s + ":00"
    return Time.fromStr(s)
  }

  private static DateTime parseDateTime(Str s)
  {
    if (s.endsWith("Z") && s.index(" ") == null) s += " UTC"
    return DateTime.fromStr(s)
  }

  private Ref parseRef(Str s)
  {
    space := s.index(" ")
    if (space == null) return Ref.make(s[2..-1], null)
    return Ref.make(s[2..<space], s[space+1..-1])
  }
}

