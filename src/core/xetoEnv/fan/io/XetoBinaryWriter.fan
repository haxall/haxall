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

**
** Writer for Xeto binary encoding of specs and data
**
@Js
class XetoBinaryWriter : XetoBinaryConst
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(XetoTransport transport, OutStream out)
  {
    this.names = transport.names
    this.maxNameCode = transport.maxNameCode
    this.out = out
  }

//////////////////////////////////////////////////////////////////////////
// Remote Env Bootstrap
//////////////////////////////////////////////////////////////////////////

  internal Void writeRemoteEnvBootstrap(MEnv env)
  {
    writeI4(magic)
    writeI4(version)
    writeNameTable
    writeRegistry(env)
    writeLib(env.sysLib)
    out.writeI4(magicEnd)
    return this
  }

  private Void writeNameTable()
  {
    max := maxNameCode
    writeVarInt(max)
    for (i := 1; i<=max; ++i)
      out.writeUtf(names.toName(i))
  }

  private Void writeRegistry(MEnv env)
  {
    env.registry.list.each |MRegistryEntry entry|
    {
      if (!entry.isLoaded) return
      lib := entry.get
      writeVarInt(lib.m.nameCode)
    }
    writeVarInt(0)
  }

//////////////////////////////////////////////////////////////////////////
// Lib
//////////////////////////////////////////////////////////////////////////

  internal Void writeLib(XetoLib lib)
  {
    writeI4(magicLib)
    writeName(lib.m.nameCode)
    writeNameDict(lib.m.meta.wrapped)
    writeTypes(lib)
    writeI4(magicLibEnd)
  }

  private Void writeTypes(XetoLib lib)
  {
    lib.types.each |type| { writeType(type) }
    writeVarInt(-1)
  }

  private Void writeType(XetoType type)
  {
    m := (MType)type.m
    writeName(m.qnameCode)
    writeName(m.nameCode)
    writeNameDict(m.metaOwn.wrapped)
    writeVarInt(m.flags)
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  Void writeVal(Obj val)
  {
    if (val === Marker.val)  return writeMarker
    if (val === NA.val)      return writeNA
    if (val === Remove.val)  return writeRemove
    type := val.typeof
    if (type === Str#)      return writeStr(val)
    if (type === Bool#)     return writeBool(val)
    if (type === DateTime#) return writeDateTime(val)
    if (val is Dict)        return writeDict(val)
    if (type === Date#)     return writeDate(val)
    if (type === Time#)     return writeTime(val)

if (type === Duration#)   return writeStr(val.toStr)
if (type === Number#)     return writeStr(val.toStr)
if (type === Float#)      return writeStr(val.toStr)
if (type === Int#)        return writeStr(val.toStr)
if (type === Ref#)        return writeStr(val.toStr)
if (type === Uri#)        return writeStr(val.toStr)
if (type === Version#)    return writeStr(val.toStr)

    throw Err("$val [$val.typeof]")
  }

  private Void writeMarker()
  {
    out.write(ctrlMarker)
  }

  private Void writeNA()
  {
    out.write(ctrlNA)
  }

  private Void writeRemove()
  {
    out.write(ctrlRemove)
  }

  private Void writeBool(Bool val)
  {
    out.write(val ? ctrlTrue : ctrlFalse)
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
      writeStr(val.tz.name) // TODO
    }
    else
    {
      out.write(ctrlDateTimeI8)
      out.writeI8(val.ticks)
      writeStr(val.tz.name) // TODO
    }
    return this
  }

  private Void writeDict(Dict d)
  {
    if (d is MNameDict) return writeNameDict(((MNameDict)d).wrapped)
    throw Err("TODO: $d.typeof")
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

  private Void write(Int byte)
  {
    out.write(byte)
  }

  private Void writeI4(Int i)
  {
    out.writeI4(i)
  }

  private Void writeUtf(Str s)
  {
    out.writeUtf(s)
  }

  private Void writeVarInt(Int val)
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


