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
    nameCode := readName
    verifyU1(ctrlNameDict, "ctrlNameDict")
    meta := readNameDict
    version := Version.fromStr((Str)meta->version)
    depends := MLibDepend[,]
    typesMap := Str:Spec[:]
    instancesMap := Str:Dict[:]

    m := MLib(env, FileLoc.synthetic, nameCode, MNameDict(meta), version, depends, typesMap, instancesMap)
    XetoLib#m->setConst(lib, m)
    return lib
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  override Obj readVal()
  {
    ctrl := in.readU1
    switch (ctrl)
    {
      case ctrlMarker:   return Marker.val
      case ctrlName:     return names.toName(readName)
      case ctrlStr:      return readUtf
      case ctrlNameDict: return readNameDict
      default:           throw IOErr("obj ctrl 0x$ctrl.toHex")
    }
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


