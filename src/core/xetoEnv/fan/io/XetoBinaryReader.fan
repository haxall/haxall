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

**
** Reader for Xeto binary encoding of specs and data
**
@Js
class XetoBinaryReader : XetoBinaryConst, NameDictReader
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(XetoTransport transport, InStream in)
  {
    this.names = transport.names
    this.maxNameCode = transport.maxNameCode
    this.in = in
  }

//////////////////////////////////////////////////////////////////////////
// Remote Env Bootstrap
//////////////////////////////////////////////////////////////////////////

  internal RemoteEnv readRemoteEnvBootstrap()
  {
    verifyU4(magic, "magic")
    verifyU4(version, "version")
    readNameTable
    registry := readRegistry
    return RemoteEnv(names, registry) |env|
    {
      sys := readLib(env)
      registry.map["sys"].set(sys)
      verifyU4(magicEnd, "magicEnd")
    }
  }

  private Void readNameTable()
  {
    max := readVarInt
    for (i := 1; i<=max; ++i)
      names.add(in.readUtf)
  }

  private RemoteRegistry readRegistry()
  {
    acc := RemoteRegistryEntry[,]
    while (true)
    {
      nameCode := readVarInt
      if (nameCode == 0) break
      name := names.toName(nameCode)
      acc.add(RemoteRegistryEntry(name))
    }
    return RemoteRegistry(acc)
  }

//////////////////////////////////////////////////////////////////////////
// Lib
//////////////////////////////////////////////////////////////////////////

  private XetoLib readLib(MEnv env)
  {
    lib := XetoLib()

    verifyU4(magicLib, "magicLib")
    nameCode  := readName
    meta      := readMeta
    version   := Version.fromStr((Str)meta->version)
    depends   := MLibDepend[,] // TODO: from meta
    types     := readTypes(env, lib)
    instances := readInstances(env, lib)
    verifyU4(magicLibEnd, "magicLibEnd")

    m := MLib(env, FileLoc.synthetic, nameCode, MNameDict(meta), version, depends, types, instances)
    XetoLib#m->setConst(lib, m)
    return lib
  }

  private Str:XetoType readTypes(MEnv env, XetoLib lib)
  {
    acc := Str:XetoType[:]
    while (true)
    {
      qnameCode := readName
      if (qnameCode < 0) break
      type := readType(env, lib, qnameCode)
      acc.add(type.name, type)
    }
    return acc
  }

  private XetoType readType(MEnv env, XetoLib lib, Int qnameCode)
  {
    type := XetoType()

    loc      := FileLoc.synthetic
    nameCode := readName
    base     := type
    meta     := MNameDict.empty
    metaOwn  := readMeta
    slots    := MSlots.empty
    slotsOwn := MSlots.empty
    flags    := readVarInt
    factory  := env.factories.dict // TODO

    m := MType(loc, env, lib, qnameCode, nameCode, base, type, meta, MNameDict(metaOwn), slots, slotsOwn, flags, factory)
    XetoSpec#m->setConst(type, m)
    return type
  }

  private Str:Dict readInstances(MEnv env, XetoLib lib)
  {
    // TODO
    acc := Str:Dict[:]
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  override Obj readVal()
  {
    ctrl := in.readU1
    switch (ctrl)
    {
      case ctrlMarker:     return Marker.val
      case ctrlNA:         return NA.val
      case ctrlRemove:     return Remove.val
      case ctrlTrue:       return true
      case ctrlFalse:      return false
      case ctrlName:       return names.toName(readName)
      case ctrlStr:        return readUtf
      case ctrlDate:       return readDate
      case ctrlTime:       return readTime
      case ctrlDateTimeI4: return readDateTimeI4
      case ctrlDateTimeI8: return readDateTimeI8
      case ctrlNameDict:   return readNameDict
      default:             throw IOErr("obj ctrl 0x$ctrl.toHex")
    }
  }

  private Date readDate()
  {
    Date(in.readU2, Month.vals[in.read-1], in.read)
  }

  private Time readTime()
  {
    Time.fromDuration(Duration(in.readU4 * 1ms.ticks))
  }

  private DateTime readDateTimeI4()
  {
    DateTime.makeTicks(in.readS4*1sec.ticks, readTimeZone)
  }

  private DateTime readDateTimeI8()
  {
    DateTime.makeTicks(in.readS8, readTimeZone)
  }

  private TimeZone readTimeZone()
  {
    TimeZone.fromStr(readVal)
  }

  private NameDict readNameDict()
  {
    size := readVarInt
    spec := null
    return names.readDict(size, this, spec)
  }

  override Int readName()
  {
    code := readVarInt
    if (code != 0) return code

    code = readVarInt
    name := readUtf
    names.set(code, name) // is now sparse
    return code
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private Int read()
  {
    in.readU1
  }

  private Str readUtf()
  {
    in.readUtf
  }

  private NameDict readMeta()
  {
    verifyU1(ctrlNameDict, "ctrlNameDict for meta")  // readMeta is **with** the ctrl code
    return readNameDict
  }

  private Void verifyU1(Int expect, Str msg)
  {
    actual := in.readU1
    if (actual != expect) throw IOErr("Invalid $msg: 0x$actual.toHex != 0x$expect.toHex")
  }

  private Void verifyU4(Int expect, Str msg)
  {
    actual := in.readU4
    if (actual != expect) throw IOErr("Invalid $msg: 0x$actual.toHex != 0x$expect.toHex")
  }

  private Int readVarInt()
  {
    v := in.readU1
    if (v == 0xff)           return -1
    if (v.and(0x80) == 0)    return v
    if (v.and(0xc0) == 0x80) return v.and(0x3f).shiftl(8).or(in.readU1)
    if (v.and(0xe0) == 0xc0) return v.and(0x1f).shiftl(8).or(in.readU1).shiftl(16).or(in.readU2)
    return in.readS8
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const NameTable names
  private const Int maxNameCode
  private InStream in
}


