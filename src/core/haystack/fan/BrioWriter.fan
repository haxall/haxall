//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Nov 2015  Brian Frank  Creation
//

**
** BrioWriter serializes Haystack data using a binary format.
**
@NoDoc @Js
class BrioWriter : GridWriter, BrioCtrl
{
  static Buf valToBuf(Obj? val)
  {
    buf := Buf()
    BrioWriter(buf.out).writeVal(val)
    return buf.flip
  }

  new make(OutStream out)
  {
    this.out = out
    this.cp = BrioConsts.cur
    this.maxStrCode = cp.maxSafeCode
  }

  Bool close() { out.close }

  This writeVal(Obj? val)
  {
    if (val == null)         return writeNull
    if (val === Marker.val)  return writeMarker
    if (val === NA.val)      return writeNA
    if (val === Remove.val)  return writeRemove
    type := val.typeof
    if (type === Bool#)     return writeBool(val)
    if (type === Number#)   return writeNumber(val)
    if (type === Str#)      return writeStr(val)
    if (type === Ref#)      return writeRef(val)
    if (type === DateTime#) return writeDateTime(val)
    if (Symbol.fits(type))  return writeSymbol(val)
    if (type === Date#)     return writeDate(val)
    if (type === Time#)     return writeTime(val)
    if (type === Uri#)      return writeUri(val)
    if (type === Coord#)    return writeCoord(val)
    if (type === XStr#)     return writeXStr(val)
    if (val is Buf)         return writeBuf(val)
    if (val is Dict)        return writeDict(val)
    if (val is Grid)        return writeGrid(val)
    if (val is List)        return writeList(val)
    if (val is BrioPreEncoded) return writePreEncoded(val)

    if (encodeUnknownAsStr) return writeStr(val.toStr)
    return writeXStr(XStr.encode(val))
  }

  private This writeNull()
  {
    out.write(ctrlNull)
    return this
  }

  private This writeMarker()
  {
    out.write(ctrlMarker)
    return this
  }

  private This writeNA()
  {
    out.write(ctrlNA)
    return this
  }

  private This writeRemove()
  {
    out.write(ctrlRemove)
    return this
  }

  private This writeBool(Bool val)
  {
    out.write(val ? ctrlTrue : ctrlFalse)
    return this
  }

  private This writeNumber(Number val)
  {
    unit := val.unit?.symbol ?: ""
    if (val.isInt)
    {
      i := val.toInt
      if (-32767 <= i && i <= 32767)
      {
        out.write(ctrlNumberI2)
        out.writeI2(i)
        encodeStr(unit)
        return this
      }
      if (-2147483648 <= i && i <= 2147483647)
      {
        out.write(ctrlNumberI4)
        out.writeI4(i)
        encodeStr(unit)
        return this
      }
    }

    out.write(ctrlNumberF8)
    out.writeF8(val.toFloat)
    encodeStr(unit)
    return this
  }

  private This writeStr(Str val)
  {
    out.write(ctrlStr)
    encodeStr(val)
    return this
  }

  private This writeUri(Uri val)
  {
    out.write(ctrlUri)
    encodeStr(val.toStr)
    return this
  }

  private This writeRef(Ref val)
  {
    val = val.toRel(encodeRefToRel)
    return writeRefId(val).writeRefDis(val)
  }

  private This writeRefId(Ref val)
  {
    i8 := refToI8(val)
    if (i8 >= 0)
    {
      out.write(ctrlRefI8)
      out.writeI8(i8)
      return this
    }

    out.write(ctrlRefStr)
    encodeStr(val.id)
    return this
  }

  private Int refToI8(Ref val)
  {
    try
    {
      // 1deb31b8-7508b187
      id := val.id
      if (id.size != 17 || id[8] != '-' || js) return -1
      i8 := 0
      for (i:=0; i<17; ++i)
      {
        if (i == 8) continue
        i8 = i8.shiftl(4).or(id[i].fromDigit(16))
      }
      return i8
    }
    catch (Err e) return -1
  }

  private This writeRefDis(Ref val)
  {
    dis := val.disVal
    if (dis == null || !encodeRefDis) dis = ""
    encodeStrChars(dis)
    return this
  }

  private This writeSymbol(Symbol val)
  {
    out.write(ctrlSymbol)
    encodeStr(val.toStr)
    return this
  }

  private This writeDate(Date val)
  {
    out.write(ctrlDate)
    out.writeI2(val.year).write(val.month.ordinal+1).write(val.day)
    return this
  }

  private This writeTime(Time val)
  {
    out.write(ctrlTime)
    out.writeI4(val.toDuration.ticks / 1ms.ticks)
    return this
  }

  private This writeDateTime(DateTime val)
  {
    ticks := val.ticks
    if (ticks % 1sec.ticks == 0)
    {
      out.write(ctrlDateTimeI4)
      out.writeI4(val.ticks/1sec.ticks)
      encodeStr(val.tz.name)
    }
    else if (js)
    {
      out.write(ctrlDateTimeF8)
      out.writeF8(val.ticks.toFloat)
      encodeStr(val.tz.name)
    }
    else
    {
      out.write(ctrlDateTimeI8)
      out.writeI8(val.ticks)
      encodeStr(val.tz.name)
    }
    return this
  }

  private This writeCoord(Coord val)
  {
    out.write(ctrlCoord)
    out.writeI4(val.packLat)
    out.writeI4(val.packLng)
    return this
  }

  private This writeXStr(XStr val)
  {
    out.write(ctrlXStr)
    encodeStr(val.type)
    encodeStr(val.val)
    return this
  }

  This writeBuf(Buf buf)
  {
    out.write(ctrlBuf)
    encodeVarInt(buf.size)
    out.writeBuf(buf)
    return this
  }

  This writeDict(Dict dict)
  {
    if (dict.isEmpty)
    {
      out.write(ctrlDictEmpty)
      return this
    }

    out.write(ctrlDict)
    out.write('{')

    // first loop is to count non-null tags
    count := 0
    dict.each |val, name| { count++ }
    encodeVarInt(count)

    // write tag name/value pairs
    dict.each |val, name|
    {
      encodeStr(name)
      writeVal(val)
    }

    out.write('}')
    return this
  }

  This writeList(Obj?[] list)
  {
    if (list.isEmpty)
    {
      out.write(ctrlListEmpty)
      return this
    }

    out.write(ctrlList)
    out.write('[')
    encodeVarInt(list.size)
    list.each |val| { writeVal(val) }
    out.write(']')
    return this
  }

  override This writeGrid(Grid grid)
  {
    out.write(ctrlGrid)
    out.write('<')

    cols := grid.cols
    encodeVarInt(cols.size)
    encodeVarInt(grid.size)

    writeDict(grid.meta)
    cols.each |col|
    {
      encodeStr(col.name)
      writeDict(col.meta)
    }
    grid.each |row|
    {
      cols.each |c| { writeVal(row.val(c)) }
    }

    out.write('>')
    return this
  }

  This writePreEncoded(BrioPreEncoded x)
  {
    out.writeBuf(x.buf.seek(0))
    return this
  }

  ** Write string value as encoded var int constant code or inline string.
  private Void encodeStr(Str val)
  {
    code := cp.encode(val, maxStrCode)
    if (code != null)
    {
      encodeVarInt(code)
    }
    else
    {
      //BrioConstTrace.trace(val)
      encodeVarInt(-1)
      encodeStrChars(val)
    }
  }

  ** Encode string size + utf-8 chars
  private Void encodeStrChars(Str val)
  {
    encodeVarInt(val.size)
    for (i := 0; i<val.size; ++i)
      out.writeChar(val[i])
  }

  ** Postive variable ints are encoding using 1, 2, 4, or 9 bytes.  We also
  ** support -1 as a special one byte 0xff encoding.  We use one to four of
  ** the most significant bits to represent length:
  **   - 0xxx: one byte (0 to 127)
  **   - 10xx: two bytes (128 to 16_383)
  **   - 110x: four bytes (16_384 to 536_870_911)
  **   - 1110: nine bytes (536_870_912 .. Int.maxVal)
  Void encodeVarInt(Int val)
  {
    if (val < 0) return out.write(0xff)
    if (val <= 0x7f) return out.write(val)
    if (val <= 0x3fff) return out.writeI2(val.or(0x8000))
    if (val <= 0x1fff_ffff) return out.writeI4(val.or(0xc000_0000))
    return out.write(0xe0).writeI8(val)
  }

  @NoDoc static const Bool js := Env.cur.runtime == "js"

  @NoDoc Str? encodeRefToRel
  @NoDoc Bool encodeRefDis := true
  @NoDoc Int maxStrCode
  @NoDoc Bool encodeUnknownAsStr
  private const BrioConsts cp
  private OutStream out
}

