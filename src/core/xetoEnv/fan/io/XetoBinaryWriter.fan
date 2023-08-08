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
** Writer for Xeto binary encoding of specs and data
**
@Js
class XetoBinaryWriter : XetoBinaryConst
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Wrap output stream
  new make(XetoTransport transport, OutStream out)
  {
    this.names = transport.names
    this.maxNameCode = transport.maxNameCode
    this.out = out
  }

//////////////////////////////////////////////////////////////////////////
// Remote Env Bootstrap
//////////////////////////////////////////////////////////////////////////

  ** Write data required for bootstrapping a remote env
  internal Void writeRemoteEnvBootstrap(MEnv env)
  {
    out.writeI4(magic)
    out.writeI4(version)
    writeNameTable
    writeRegistry(env)
    out.writeI4(magicEnd)
    return this
  }

  ** Write name table:
  **   - varInt: max name code
  **   - utf*: names
  private Void writeNameTable()
  {
    max := maxNameCode
    writeVarInt(max)
    for (i := 1; i<=max; ++i)
      out.writeUtf(names.toName(i))
  }

  ** Write all loaded libs:
  **   - varInt*: name code for each loaded lib
  **   - zero
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
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Postive variable ints are encoding using 1, 2, 4, or 9 bytes.  We also
  ** support -1 as a special one byte 0xff encoding.  We use one to four of
  ** the most significant bits to represent length:
  **   - 0xxx: one byte (0 to 127)
  **   - 10xx: two bytes (128 to 16_383)
  **   - 110x: four bytes (16_384 to 536_870_911)
  **   - 1110: nine bytes (536_870_912 .. Int.maxVal)
  ** This encoding is same as Brio.
  Void writeVarInt(Int val)
  {
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


