//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Feb 2016  Brian Frank  Creation
//

**
** BlobMeta provides up to 32 bytes available in RAM for each
** blob for indexing meta data.
**
native const final class BlobMeta
{
  ** Constructor from buffer
  static new fromBuf(Buf buf)

  ** Size in bytes
  Int size()

  ** Convenience for `readU1`
  @Operator Int get(Int index)

  ** Get one byte as unsigned 8-bit integer at given index
  Int readU1(Int index)

  ** Read unsigned two byte integer starting at given index
  Int readU2(Int index)

  ** Read unsigned four byte integer starting at given index
  Int readU4(Int index)

  ** Read signed one byte integer starting at given index
  Int readS1(Int index)

  ** Read signed two byte integer starting at given index
  Int readS2(Int index)

  ** Read signed four byte integer starting at given index
  Int readS4(Int index)

  ** Read signed eight byte integer starting at given index
  Int readS8(Int index)

}

