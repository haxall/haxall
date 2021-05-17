//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  30 Mar 2021   Matthew Giannini  Creation
//

**
** Utilities for reading/writing the primitive MQTT data types.
**
mixin DataCodec
{
  private static const Int uint8_max  := 255
  private static const Int uint16_max := 64_535
  private static const Int uint32_max := 4_294_967_295
  private static const Int vbi_max    := 268_435_455
  private static const Int maxStr     := uint16_max

  private static InStream toIn(Obj obj)
  {
    if (obj is InStream) return obj
    if (obj is Buf) return ((Buf)obj).in
    throw ArgErr("Cannot convert to InStream: $obj ($obj.typeof)")
  }

  private static OutStream toOut(Obj obj)
  {
    if (obj is OutStream) return obj
    if (obj is Buf) return ((Buf)obj).out
    throw ArgErr("Cannot convert to OutStream: $obj ($obj.typeof)")
  }

  ** Write an unsigned byte
  static Void writeByte(Int val, Obj out)
  {
    toOut(out).write(checkRange(0, val, uint8_max))
  }

  ** Read an unsigned byte
  static Int readByte(Obj in)
  {
    toIn(in).read
  }

  ** Write a 2-byte unsigned integer
  static Void writeByte2(Int val, Obj out)
  {
    toOut(out).writeI2(checkRange(0, val, uint16_max))
  }

  ** Read a 2-byte unsigned integer
  static Int readByte2(Obj in)
  {
    toIn(in).readU2
  }

  ** Write a 4-byte unsigned integer
  static Void writeByte4(Int val, Obj out)
  {
    toOut(out).writeI4(checkRange(0, val, uint32_max))
  }

  ** Read a 4-byte unsigned integer
  static Int readByte4(Obj in)
  {
    toIn(in).readU4
  }

  ** Write a Variable-Byte Integer (VBI)
  static Void writeVbi(Int val, Obj obj)
  {
    checkRange(0, val, vbi_max)
    out := toOut(obj)
    while (true)
    {
      byte := val % 128
      val = val / 128
      // if there is more data to encode, set the top bit of this byte
      if (val > 0) byte = byte.or(128)
      out.write(byte)
      if (val <= 0) break
    }
  }

  ** Read a Variable-Byte Integer (VBI)
  static Int readVbi(Obj obj)
  {
    in         := toIn(obj)
    multiplier := 1
    value      := 0
    while (true)
    {
      byte := in.read
      value += byte.and(127) * multiplier
      if (multiplier > 128*128*128)
        throw IOErr("Malformed Variable Byte Integer")
      multiplier *= 128
      if (byte.and(128) == 0) break
    }
    return value
  }

  private static Int checkRange(Int min, Int val, Int max)
  {
    if (val < min || val > max) throw ArgErr("Out-of-range: $val")
    return val
  }

  ** Write a UTF8 string
  static Void writeUtf8(Str? str, Obj obj)
  {
    out := toOut(obj)
    if (str == null) str = ""
    bytes := str.toBuf
    if (bytes.size > maxStr) throw ArgErr("Str is too big: ${bytes.size} bytes")
    out.writeI2(bytes.size)
    out.writeBuf(bytes)
  }

  ** Read a UTF8 string
  static Str readUtf8(Obj obj)
  {
    in  := toIn(obj)
    len := in.readU2
    if (len == 0) return ""
    return in.readBufFully(null, len).readAllStr
  }

  ** Write binary data
  static Void writeBin(Buf? data, Obj out)
  {
    if (data == null) return writeByte2(0, out)

    writeByte2(data.size, out)
    toOut(out).writeBuf(data)
  }

  ** Read binary data
  static Buf readBin(Obj in)
  {
    len := readByte2(in)
    return toIn(in).readBufFully(null, len)
  }

  ** Write a UTF8 String Pair
  static Void writeStrPair(StrPair pair, Obj out)
  {
    writeUtf8(pair.name, out)
    writeUtf8(pair.val, out)
  }

  ** Read a UTF8 String Pair
  static StrPair readStrPair(Obj in)
  {
    name := readUtf8(in)
    val  := readUtf8(in)
    return StrPair(name, val)
  }

  ** Write `Properties`
  static Void writeProps(Properties? props, Obj out)
  {
    // short-circuit if no props
    if (props == null || props.isEmpty) return writeVbi(0, out)

    // encode properties into temp buf
    buf := Buf()
    props.each |val, prop|
    {
      // property id
      writeVbi(prop.id, buf)

      // property value
      switch (prop.type)
      {
        case DataType.byte:    writeByte(val, buf)
        case DataType.byte2:   writeByte2(val, buf)
        case DataType.byte4:   writeByte4(val, buf)
        case DataType.utf8:    writeUtf8(val, buf)
        case DataType.vbi:     writeVbi(val, buf)
        case DataType.binary:  writeBin(val, buf)
        case DataType.strPair: writeStrPair(val, buf)
        default: throw Err("Unexpected property type: ${prop}")
      }
    }

    // now write length + properties into output buf
    writeVbi(buf.size, out)
    toOut(out).writeBuf(buf.flip)
  }

  ** Read `Properties
  static Properties readProps(Obj in)
  {
    props := Properties()
    len   := readVbi(in)
    if (len == 0) return props

    buf := toIn(in).readBufFully(null, len)
    while (buf.more)
    {
      id   := readVbi(buf)
      prop := Property.fromId(id)
      Obj? val := null
      switch (prop.type)
      {
        case DataType.byte:    val = readByte(buf)
        case DataType.byte2:   val = readByte2(buf)
        case DataType.byte4:   val = readByte4(buf)
        case DataType.utf8:    val = readUtf8(buf)
        case DataType.vbi:     val = readVbi(buf)
        case DataType.binary:  val = readBin(buf)
        case DataType.strPair: val = readStrPair(buf)
        default: throw Err("Unexpected property type: ${prop}")
      }
      props.add(prop, val)
    }

    return props
  }
}

**************************************************************************
** DataType
**************************************************************************

**
** MQTT data types
**
enum class DataType
{
  byte,
  byte2,
  byte4,
  utf8,
  vbi,    // variable byte integer
  binary,
  strPair // utf8 string pair
}