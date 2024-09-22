//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

**
** Xeto documentation writer
**
abstract class DocWriter
{
  abstract Void writeLib(DocLib lib)

  abstract Void writeType(DocSpec type)
}

