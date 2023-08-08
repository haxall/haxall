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
** Transport for I/O of Xeto specs and data across network.
** An instance of XetoTransport is used on both client and server endpoints.
**
@Js
class XetoTransport
{
  ** Construct with name table
  private new make(NameTable names)
  {
    this.names = names
    this.maxNameCode = names.maxCode
  }

  ** Shared name table up to maxNameCode
  const NameTable names

  ** Max name code (inclusive)
  const Int maxNameCode

  ** Write boostrap data  for a remote env client to given output
  ** stream and return new transport for server endpoint.
  static XetoTransport writeEnvBootstrap(XetoEnv local, OutStream out)
  {
    transport := make(local.names)
    XetoBinaryWriter(transport, out).writeRemoteEnvBootstrap(local)
    return transport
  }

  ** Read boostrap data and create new RemoteEnv instance
  static RemoteEnv readEnvBootstrap(InStream in)
  {
    XetoBinaryReader(make(NameTable()), in).readRemoteEnvBootstrap
  }
}


