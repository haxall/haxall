//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Oct 2025  Brian Frank  Creation
//

using xeto
using xetom

**
** If compiling the companion lib, then attept to reuse func thunks
**
@Js
internal class ReuseThunks : Step
{
  override Void run()
  {
    if (!isCompanion) return

    thunks := ns.companionRecs?.thunks
    if (thunks == null) return

    lib := compiler.lib.asm
    thunks.each |thunk, name|
    {
      spec := lib.spec(name, false)
      if (spec == null || !spec.isFunc) return
      ((MFunc)spec.func).setThunk(thunk)
    }
  }
}

