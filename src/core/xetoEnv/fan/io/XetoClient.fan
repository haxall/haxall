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
** Network client transport
**
@Js
abstract const class XetoClient : XetoTransport
{

  ** Environment for the transport
  override MEnv env() { envRef.val ?: throw Err("Not booted") }
  internal const AtomicRef envRef := AtomicRef()

  ** Shared name table up to maxNameCode
  override const NameTable names := NameTable()

  ** Clients can always safely use every name they have mapped from server
  override Int maxNameCode() { Int.defVal }

  ** Asynchronously load a library
  abstract Void loadLib(Str qname, |Lib?| f)
}


