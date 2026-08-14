//
// Copyright (c) 2013, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2011  Brian Frank  Creation
//

using util
using xeto

**
** Write Haystack data in [Hayson](ph.doc::Json) format, the JSON encoding
** where a typed scalar is an object naming its own kind.
**
@Js
class HaysonWriter : GridWriter
{

//////////////////////////////////////////////////////////////////////////
// Convenience
//////////////////////////////////////////////////////////////////////////

  **
  ** Get a value as a Hayson string.
  **
  static Str valToStr(Obj? val)
  {
    buf := StrBuf()
    HaysonWriter(buf.out).writeVal(val)
    return buf.toStr
  }

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Wrap output stream.
  **
  ** ```fantom
  ** HaysonWriter(out).writeVal(Etc.makeDict(["ts": DateTime.now])).close
  ** ```
  **
  ** The legacy Haystack 3 encoding is still written via the 'v3' option,
  ** which is retained for existing clients and is not part of the
  ** documented API.
  new make(OutStream out, Dict? opts := null)
  {
    this.out  = JsonOutStream(out)
    this.opts = opts ?: Etc.dict0
  }

  @NoDoc JsonOutStream out

  Dict opts { private set }

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  ** Flush the underlying output stream and return this
  This flush() { out.flush; return this }

  ** Close the underlying output stream
  Bool close() {  out.close }

  ** Write any haystack value
  This writeVal(Obj? val)
  {
    if (HaysonParserBase.isV3(opts))
      HaysonV3Writer(out).writeVal(val)
    else
      HaysonV4Writer(out).writeVal(val)
    return this
  }

  ** Write the grid and return this
  override This writeGrid(Grid grid) { writeVal(grid) }
}

**************************************************************************
** HaysonV4Writer
**************************************************************************

@Js internal class HaysonV4Writer : GridWriter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Wrap output stream
  new make(JsonOutStream out) { this.out = out }

  private JsonOutStream out

  internal static const TimeZone gmt := TimeZone("GMT")

//////////////////////////////////////////////////////////////////////////
// HaysonV4Writer
//////////////////////////////////////////////////////////////////////////

  ** Write any Haystack value
  This writeVal(Obj? val)
  {
    if (val is List) return writeList(val)
    if (val is Dict) return writeDict(val)
    if (val is Grid) return writeGrid(val)
    writeScalar(val)
    return this
  }

  ** Write the grid and return this
  override This writeGrid(Grid grid)
  {
    // grid begin
    out.print("{\n")

    // kind
    out.printLine(Str<|"_kind": "grid",|>)

    // meta
    out.print(Str<|"meta": {"ver":"3.0"|>)
    writeDictTags(grid.meta, false)
    out.print("},\n")

    // columns
    out.printLine(Str<|"cols": [|>)
    firstCol := true
    grid.cols.each |col, i|
    {
      if (firstCol) firstCol = false; else out.print(",\n")
      out.print("{")
      out.print(Str<|"name":|>).print(col.name.toCode)
      if (!col.meta.isEmpty)
      {
        out.print(",")
        out.print(Str<|"meta":|>)
        writeDict(col.meta)
      }
      out.print("}")
    }
    out.print("\n],\n")

    // rows
    out.printLine(Str<|"rows":[|>)
    firstRow := true
    grid.each |row|
    {
      if (firstRow) firstRow = false; else out.print(",\n")
      writeDict(row)
    }
    out.print("\n]\n")

    // grid end
    out.print("}\n").flush
    return this
  }

  ** Write dict
  private This writeDict(Dict dict)
  {
    out.print("{")
    writeDictTags(dict, true)
    out.print("}")
    return this
  }

  ** Write list
  private This writeList(Obj?[] list)
  {
    out.print("[")
    first := true
    list.each |val|
    {
      if (first) first = false; else out.print(", ")
      writeVal(val)
    }
    out.print("]")
    return this
  }

  private Void writeDictTags(Dict dict, Bool first)
  {
    dict.each |val, name|
    {
      if (first) first = false; else out.print(", ")
      out.print(name.toCode).print(":")
      writeVal(val)
    }
  }

  private Void writeScalar(Obj? val)
  {
    if (val == null)             out.writeJson(null)
    else if (val is Str)         out.writeJson(val)
    else if (val is Bool)        out.writeJson(val)
    else if (val is Num)         out.writeJson(val)
    else if (val is Number)      writeNumber(val)
    else if (val is Ref)         writeRef(val)
    else if (val is Date)        writeDate(val)
    else if (val is Time)        writeTime(val)
    else if (val is DateTime)    writeDateTime(val)
    else if (val is Uri)         writeUri(val)
    else if (val is Symbol)      writeSymbol(val)
    else if (val is Coord)       writeCoord(val)
    else if (val is XStr)        writeXStr(val)
    else if (val === Marker.val) out.print(Str<|{"_kind":"marker"}|>)
    else if (val === None.val)   out.print(Str<|{"_kind":"remove"}|>)
    else if (val === NA.val)     out.print(Str<|{"_kind":"na"}|>)
    else if (val is Span)        writeScalar(XStr(val))
    else if (val is Bin)         writeScalar(XStr(val))
    else throw Err("Unrecognized scalar: $val (${val?.typeof})")
  }

  private Void writeNumber(Number val)
  {
    num  := val.isInt ? val.toInt : val.toFloat
    unit := val.unit
    if (val.isSpecial)
    {
      f := val.toFloat
      v := "NaN"
      if (f == Float.posInf)      v = "INF"
      else if (f == Float.negInf) v = "-INF"
      writeKind("number", ["val": v])
    }
    else if (unit == null)
    {
      out.writeJson(num)
    }
    else
    {
      writeKind("number", ["val": num, "unit": unit.toStr])
    }
  }

  private Void writeRef(Ref ref)
  {
    if (ref.disVal != null)
      writeKind("ref", ["val": ref.id, "dis": ref.dis])
    else
      writeKind("ref", ["val": ref.id])
  }

  private Void writeDate(Date date)
  {
    writeKind("date", ["val": date.toStr])
  }

  private Void writeTime(Time time)
  {
    writeKind("time", ["val": time.toStr])
  }

  private Void writeDateTime(DateTime ts)
  {
    attrs := ["val": ts.toIso]
    if (ts.tz != gmt) attrs["tz"] = ts.tz.toStr
    writeKind("dateTime", attrs)
  }

  private Void writeUri(Uri uri)
  {
    writeKind("uri", ["val": uri.toStr])
  }

  private Void writeSymbol(Symbol s)
  {
    writeKind("symbol", ["val": s.toStr])
  }

  private Void writeCoord(Coord c)
  {
    writeKind("coord", ["lat": c.lat, "lng": c.lng])
  }

  private Void writeXStr(XStr x)
  {
    writeKind("xstr", ["type": x.type, "val": x.val])
  }

  private Void writeKind(Str kind, Map attrs)
  {
    out.print(Str<|{"_kind":|>).writeJson(kind)
    writeDictTags(Etc.makeDict(attrs), false)
    out.print("}")
  }
}

**************************************************************************
** HaysonV3Writer
**************************************************************************

@Js internal class HaysonV3Writer : GridWriter
{
  new make(JsonOutStream out) { this.out = out }

  private JsonOutStream out

  ** Write value
  This writeVal(Obj? val)
  {
    if (val is List) return writeList(val)
    if (val is Dict) return writeDict(val)
    if (val is Grid) return writeGrid(val)
    writeScalar(val)
    return this
  }

  ** Write grid and return this
  override This writeGrid(Grid grid)
  {
    // grid begin
    out.print("{\n")

    // meta
    out.print(Str<|"meta": {"ver":"3.0"|>)
    writeDictTags(grid.meta, false)
    out.print("},\n")

    // columns
    out.print(Str<|"cols":[|>).print("\n")
    firstCol := true
    grid.cols.each |col, i|
    {
      if (firstCol) firstCol = false; else out.print(",\n")
      out.print(Str<|{"name":|>).print(col.name.toCode)
      writeDictTags(col.meta, false)
      out.print("}")
    }
    out.print("\n],\n")

    // rows
    out.print(Str<|"rows":[|>).print("\n")
    firstRow := true
    grid.each |row|
    {
      if (firstRow) firstRow = false; else out.print(",\n")
      writeDict(row)
    }
    out.print("\n]\n")

    // grid end
    out.print("}\n")
    out.flush
    return this
  }

  ** Write dict
  private This writeDict(Dict dict)
  {
    out.print("{")
    writeDictTags(dict, true)
    out.print("}")
    return this
  }

  ** Write list
  private This writeList(Obj?[] list)
  {
    out.print("[")
    first := true
    list.each |val|
    {
      if (first) first = false; else out.print(", ")
      writeVal(val)
    }
    out.print("]")
    return this
  }

  private Void writeDictTags(Dict dict, Bool first)
  {
    dict.each |val, name|
    {
      if (first) first = false; else out.print(", ")
      out.print(name.toCode).print(":")
      writeVal(val)
    }
  }

  private Void writeScalar(Obj? val)
  {
    if (val == null)
      out.writeJson(null);
    else if (val is Bool)
      out.writeJson(val)
    else
      out.writeJson(Kind.fromVal(val).valToJson(val))
  }

}

