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
** This is the base class for XetoClient and XetoServer.
**
@Js
abstract const class XetoTransport
{

  ** Environment for the transport
  abstract MEnv env()

  ** Shared name table up to maxNameCode
  abstract NameTable names()

  ** Max name code (inclusive) that safe to use
  abstract Int maxNameCode()

}


