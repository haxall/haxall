//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Aug 2023  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack::Marker
using haystack::NA
using haystack::Remove
using haystack::Number
using haystack::Ref
using haystack::Coord
using haystack::Symbol
using haystack::Grid

**
** Writer for Xeto binary encoding of specs and data
**
** NOTE: this encoding is not backward/forward compatible - it only
** works with XetoBinaryReader of the same version
**
@Js
class XetoBinaryWriter : XetoBinaryConst
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  internal new make(XetoBinaryIO io, OutStream out)
  {
    this.names = io.names
    this.maxNameCode = io.maxNameCode
    this.out = out
  }

//////////////////////////////////////////////////////////////////////////
// Remote Env Bootstrap
//////////////////////////////////////////////////////////////////////////

  Void writeBoot(XetoEnv env, Lib[] libs)
  {
    writeI4(magic)
    writeI4(version)
    writeNameTable
    writeRegistry(libs)
    writeLib(env.sysLib)
    out.writeI4(magicEnd)
    return this
  }

  private Void writeNameTable()
  {
    max := maxNameCode
    writeVarInt(max)
    for (i := NameTable.initSize+1; i<=max; ++i)
      out.writeUtf(names.toName(i))
  }

  private Void writeRegistry(Lib[] libs)
  {
    writeVarInt(libs.size)
    libs.each |lib|
    {
      writeRegistryEntry(lib)
    }
  }

  private Void writeRegistryEntry(XetoLib lib)
  {
    writeI4(magicReg)
    writeName(lib.m.nameCode)
    writeVarInt(lib.depends.size)
    lib.depends.each |d| { writeName(names.toCode(d.name)) }
  }

//////////////////////////////////////////////////////////////////////////
// Lib
//////////////////////////////////////////////////////////////////////////

  Void writeLib(XetoLib lib)
  {
    writeI4(magicLib)
    writeName(lib.m.nameCode)
    writeNameDict(lib.m.meta.wrapped)
    writeTops(lib)
    writeInstances(lib)
    writeI4(magicLibEnd)
  }

  private Void writeTops(XetoLib lib)
  {
    lib.tops.each |x| { writeSpec(x) }
    writeVarInt(-1)
  }

  private Void writeSpec(XetoSpec x)
  {
    m := x.m
    writeName(m.nameCode)
    writeSpecRef(m.base)
    writeSpecRef(m.isType ? null : m.type)
    writeNameDict(m.metaOwn.wrapped)
    writeSlots(x)
    writeVarInt(m.flags)
  }

  private Void writeSlots(XetoSpec x)
  {
    slots := x.m.slotsOwn.map
    size := slots.size
    writeVarInt(size)
    for (i := 0; i<size; ++i)
      writeSpec(slots.valAt(i))
  }

  private Void writeSpecRef(XetoSpec? spec)
  {
    if (spec == null) { write(0); return }
    if (spec.parent == null)
    {
      write(1)
      writeName(spec.m.lib.m.nameCode)
      writeName(spec.m.nameCode)
    }
    else if (spec.parent.parent == null)
    {
      write(2)
      writeName(spec.m.lib.m.nameCode)
      writeName(spec.m.parent.m.nameCode)
      writeName(spec.m.nameCode)
    }
    else
    {
      // build path up to type
      throw Err("TODO")
    }
  }

  private Void writeInstances(XetoLib lib)
  {
    lib.m.instancesMap.each |x| { writeNameDict(((MNameDict)x).wrapped) }
    write(0)  // end with control byte zero instead NameDict control byte
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  Void writeVal(Obj? val)
  {
    // haystack
    if (val == null)         return writeNull
    if (val === Marker.val)  return writeMarker
    if (val === NA.val)      return writeNA
    if (val === Remove.val)  return writeRemove
    type := val.typeof
    if (type === Str#)      return writeStr(val)
    if (type === Number#)   return writeNumber(val)
    if (type === Ref#)      return writeRef(val)
    if (type === DateTime#) return writeDateTime(val)
    if (val is Dict)        return writeDict(val)
    if (val is List)        return writeList(val)
    if (type === Bool#)     return writeBool(val)
    if (type === Date#)     return writeDate(val)
    if (type === Time#)     return writeTime(val)
    if (type === Uri#)      return writeUri(val)
    if (type === Coord#)    return writeCoord(val)
    if (val is Grid)        return writeGrid(val)
    if (val is Symbol)      return writeSymbol(val)

    // non-haystack
    if (type === Int#)      return writeInt(val)
    if (type === Float#)    return writeFloat(val)
    if (type === Duration#) return writeDuration(val)
    if (type === Version#)  return writeVersion(val)

echo("TODO: XetoBinaryWriter.writeVal $val [$val.typeof]")
    writeStr(val.toStr)
  }

  private Void writeNull()
  {
    write(ctrlNull)
  }

  private Void writeMarker()
  {
    write(ctrlMarker)
  }

  private Void writeNA()
  {
    write(ctrlNA)
  }

  private Void writeRemove()
  {
    write(ctrlRemove)
  }

  private Void writeBool(Bool val)
  {
    write(val ? ctrlTrue : ctrlFalse)
  }

  private Void writeStr(Str s)
  {
    nameCode := names.toCode(s)
    if (nameCode > 0 && nameCode <= maxNameCode)
    {
      write(ctrlName)
      writeVarInt(nameCode)
    }
    else
    {
      write(ctrlStr)
      writeUtf(s)
    }
  }

  private This writeNumber(Number val)
  {
    unit := val.unit?.symbol
    if (unit == null)
    {
      write(ctrlNumberNoUnit)
      writeF8(val.toFloat)
    }
    else
    {
      write(ctrlNumberUnit)
      writeF8(val.toFloat)
      writeUtf(unit)
    }
    return this
  }

  private Void writeInt(Int val)
  {
    if (-32767 <= val && val <= 32767)
    {
      write(ctrlInt2)
      writeI2(val)
    }
    else
    {
      write(ctrlInt8)
      writeI8(val)
    }
  }

  private Void writeFloat(Float val)
  {
    write(ctrlFloat8)
    writeF8(val)
  }

  private Void writeDuration(Duration val)
  {
    write(ctrlDuration)
    writeI8(val.ticks)
  }

  private Void writeUri(Uri uri)
  {
    write(ctrlUri)
    writeUtf(uri.toStr)
  }

  private Void writeRef(Ref ref)
  {
    write(ctrlRef)
    writeUtf(ref.id)
    writeUtf(ref.disVal ?: "")
  }

  private This writeDate(Date val)
  {
    write(ctrlDate)
    out.writeI2(val.year).write(val.month.ordinal+1).write(val.day)
    return this
  }

  private This writeTime(Time val)
  {
    write(ctrlTime)
    writeI4(val.toDuration.ticks / 1ms.ticks)
    return this
  }

  private This writeDateTime(DateTime val)
  {
    ticks := val.ticks
    secs := ticks / 1sec.ticks
    millis := (ticks % 1sec.ticks) / 1ms.ticks
    write(ctrlDateTime)
    writeI4(secs)
    writeI2(millis)
    writeStr(val.tz.name) // TODO
    return this
  }

  private This writeVersion(Version val)
  {
    write(ctrlVersion)
    writeUtf(val.toStr)
    return this
  }

  private This writeCoord(Coord val)
  {
    write(ctrlCoord)
    writeUtf(val.toStr)
    return this
  }

  private This writeSymbol(Symbol symbol)
  {
    out.write(ctrlSymbol)
    out.writeUtf(symbol.toStr)
    return this
  }

  Void writeDict(Dict d)
  {
    if (d.isEmpty)      return write(ctrlEmptyDict)
    if (d is NameDict)  return writeNameDict(d)
    if (d is MNameDict) return writeNameDict(((MNameDict)d).wrapped)
    if (d is XetoSpec)  return writeSpecRefVal(d)
    return writeGenericDict(d)
  }

  private Void writeSpecRefVal(XetoSpec spec)
  {
    write(ctrlSpecRef)
    writeSpecRef(spec)
  }

  private Void writeNameDict(NameDict dict)
  {
    write(ctrlNameDict)
    size := dict.size
    writeVarInt(size)
    for (i := 0; i<size; ++i)
    {
      writeName(dict.nameAt(i))
      writeVal(dict.valAt(i))
    }
  }

  private Void writeGenericDict(Dict dict)
  {
    write(ctrlGenericDict)
    dict.each |v, n|
    {
      writeStr(n)
      writeVal(v)
    }
    writeStr("")
  }

  Void writeList(Obj?[] list)
  {
    write(ctrlList)
    writeVarInt(list.size)
    list.each |x|
    {
      writeVal(x)
    }
  }

  Void writeGrid(Grid grid)
  {
    write(ctrlGrid)

    cols := grid.cols
    writeVarInt(cols.size)
    writeVarInt(grid.size)

    writeDict(grid.meta)
    cols.each |col|
    {
      writeStr(col.name)
      writeDict(col.meta)
    }
    grid.each |row|
    {
      cols.each |c| { writeVal(row.val(c)) }
    }
  }

  private Void writeName(Int nameCode)
  {
    if (nameCode <= maxNameCode)
    {
      writeVarInt(nameCode)
    }
    else
    {
      out.write(0)
      writeVarInt(nameCode)
      out.writeUtf(names.toName(nameCode))
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void write(Int byte)
  {
    out.write(byte)
  }

  Void writeI2(Int i)
  {
    out.writeI2(i)
  }

  Void writeI4(Int i)
  {
    out.writeI4(i)
  }

  Void writeI8(Int i)
  {
    out.writeI8(i)
  }

  Void writeF8(Float f)
  {
    out.writeF8(f)
  }

  Void writeUtf(Str s)
  {
    out.writeUtf(s)
  }

  Void writeRawRefList(Ref[] ids)
  {
    writeVarInt(ids.size)
    ids.each |id| { writeUtf(id.id) }
  }

  Void writeRawDictList(Dict[] dicts)
  {
    writeVarInt(dicts.size)
    dicts.each |d| { writeDict(d) }
  }

  Void writeVarInt(Int val)
  {
    // see BrioWriter.encodeVarInt - same encoding
    if (val < 0) return out.write(0xff)
    if (val <= 0x7f) return out.write(val)
    if (val <= 0x3fff) return out.writeI2(val.or(0x8000))
    if (val <= 0x1fff_ffff) return out.writeI4(val.or(0xc000_0000))
    return out.write(0xe0).writeI8(val)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const NameTable names
  private const Int maxNameCode
  private OutStream out
}


