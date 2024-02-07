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
**
@Js
const class XetoTransport
{
  ** Constructor to wrap given local environment
  new makeServer(MEnv env)
  {
    this.names = env.names
    this.maxNameCode = names.maxCode
  }

  ** Constructor to load RemoteEnv
  new makeClient()
  {
    this.names = NameTable()       // start off with empty name table
    this.maxNameCode = Int.maxVal  // can safely use every name mapped from server
  }

  ** Shared name table up to maxNameCode
  const NameTable names

  ** Max name code (inclusive) that safe to use
  const Int maxNameCode

}