//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Nov 2026  Brian Frank  Creation
//

**
** SrcStr is implemented by scalars whose value is source code such
** as Axon or Sketch templates.  The string is wrapped as-is; parsing
** and compiling is left to each language's own APIs.
**
@NoDoc @Js
const mixin SrcStr
{
  ** Source code
  abstract Str src()

  ** Return source code
  override Str toStr() { src }
}

