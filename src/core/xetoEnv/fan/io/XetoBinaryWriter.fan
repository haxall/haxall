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
** NOTE: this encoding is not backward/forward compatible - it only
** works with XetoBinaryReader of the same version
**
@Js
class XetoBinaryWriter : XetoBinaryConst
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(XetoTransport transport, OutStream out)
  {
    this.transport = transport
    this.names = transport.names
    this.maxNameCode = transport.maxNameCode
    this.out = out
  }

//////////////////////////////////////////////////////////////////////////
// Remote Env Bootstrap
//////////////////////////////////////////////////////////////////////////

  Void writeBoot()
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
    for (i := NameTable.initSize+1; i<=max; ++i)
      out.writeUtf(names.toName(i))
  }

  private Void writeRegistry(MEnv env)
  {
    env.registry.list.each |MRegistryEntry entry|
    {
      if (entry.isLoaded) writeRegistryEntry(entry.get)
    }
    writeVarInt(0)
  }

  private Void writeRegistryEntry(XetoLib lib)
  {
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
    writeTypes(lib)
    writeI4(magicLibEnd)
  }

  private Void writeTypes(XetoLib lib)
  {
    lib.types.each |type| { writeSpec(type) }
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
    if (spec.isType)
    {
      write(1)
      writeName(spec.m.lib.m.nameCode)
      writeName(spec.m.nameCode)
    }
    else if (spec.parent.isType)
    {
      write(2)
      writeName(spec.m.lib.m.nameCode)
      writeName(spec.m.parent.m.nameCode)
      writeName(spec.m.nameCode)
    }
    else if (spec.parent.isType)
    {
      // build path up to type
      throw Err("TODO")
    }
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
    if (type === Ref#)      return writeRef(val)
    if (type === DateTime#) return writeDateTime(val)
    if (val is Dict)        return writeDict(val)
    if (type === Bool#)     return writeBool(val)
    if (type === Date#)     return writeDate(val)
    if (type === Time#)     return writeTime(val)
    if (type === Uri#)      return writeUri(val)

if (type === Duration#)   return writeStr(val.toStr)
if (type === Number#)     return writeStr(val.toStr)
if (type === Float#)      return writeStr(val.toStr)
if (type === Int#)        return writeStr(val.toStr)
if (type === Version#)    return writeStr(val.toStr)
if (val is List)          return writeStr(val.toStr)

echo("TODO: XetoBinaryWriter.writeVal $val [$val.typeof]")
    writeStr(val.toStr)
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

  private Void writeUri(Uri uri)
  {
    write(ctrlUri)
    writeUtf(uri.toStr)
  }

  private Void writeRef(Ref ref)
  {
    write(ctrlRef)
    writeUtf(ref.id)
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

  Void writeI4(Int i)
  {
    out.writeI4(i)
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

  MEnv env() { transport.env }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const XetoTransport transport
  private const NameTable names
  private const Int maxNameCode
  private OutStream out
}


