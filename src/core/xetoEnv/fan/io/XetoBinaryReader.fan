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

**
** Reader for Xeto binary encoding of specs and data
**
@Js
class XetoBinaryReader : XetoBinaryConst
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
names.dump(Env.cur.out)
    verifyU4(magicEnd, "magicEnd")
    return RemoteEnv(names, RemoteRegistry(["sys"]))
  }

  private Void readNameTable()
  {
    max := readVarInt
    for (i := 1; i<=max; ++i)
      names.add(in.readUtf)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private Void verifyU4(Int expect, Str msg)
  {
    actual := in.readU4
    if (actual != expect) throw IOErr("Invalid $msg: 0x$actual.toHex != 0x$expect.toHex")
  }

  Int readVarInt()
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


