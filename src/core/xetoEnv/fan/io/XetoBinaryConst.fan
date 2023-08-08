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
** Xeto binary constants
**
@Js
mixin XetoBinaryConst
{
  static const Int magic    := 0x78623233   // xb23
  static const Int magicEnd := 0x78623233   // XB};
  static const Int version  := 0x2023_08
}


