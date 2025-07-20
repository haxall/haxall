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
** XetoBinaryIO manages the factory to create binary reader/writers.
** When a client is first booted, we loaded the whole name table from
** the server. But from that point onwards the server cannot use any
** name code added after boot since the client won't have it cached.
**
@Js
const class XetoBinaryIO
{
  ** Constructor to wrap given local namespace
  new makeServer(MNamespace ns)
  {
  }

  ** Constructor for booting client used by RemotNamespace.boot
  internal new makeClientStart()
  {
  }

  ** Constructor before making RemoteNamespace to lock down maxNameCode
  internal new makeClientEnd()
  {
  }

  ** Create a new writer
  XetoBinaryWriter writer(OutStream out)
  {
    XetoBinaryWriter(this, out)
  }

  ** Create a new reader
  XetoBinaryReader reader(InStream in)
  {
    XetoBinaryReader(this, in)
  }

  ** Max name code (inclusive) that safe to use
  const Int maxNameCode

}

