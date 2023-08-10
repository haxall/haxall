//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Aug 2023  Brian Frank  Creation
//

using concurrent
using util
using xeto

**
** Server session to one XetoClient over a network
**
@Js
abstract const class XetoServer : XetoTransport
{
  ** Constructor to wrap given local environment
  new make(MEnv env)
  {
    this.env = env
    this.names = env.names
    this.maxNameCode = names.maxCode
  }

  ** Environment for the transport
  override const MEnv env

  ** Shared name table up to maxNameCode
  override const NameTable names

  ** Clients can always safely use every name they have mapped from server
  override const Int maxNameCode
}


