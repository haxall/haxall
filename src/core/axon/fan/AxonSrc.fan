//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Mar 2026  Brian Frank  Creation
//   1 Nov 2026  Brian Frank  Rename from AxonExpr
//

using xeto

**
** AxonSrc wraps Axon source code for functions and expressions
**
@Js @NoDoc
const class AxonSrc : SrcStr
{
  ** Wrap string - the string is *not* parsed for syntax correctness
  static new fromStr(Str src) { make(src) }

  ** Constructor
  private new make(Str src) { this.src = src }

  ** Source code
  override const Str src

  ** Hash is based on source code
  override Int hash() { src.hash }

  ** Equality is based on source code
  override Bool equals(Obj? that)
  {
    x := that as AxonSrc
    return x != null && src == x.src
  }
}

