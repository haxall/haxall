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
    funcs := lib.spec("Funcs", false)
    if (funcs == null) return funcs

    thunks.each |thunk, name|
    {
      spec := funcs.slot(name, false)
      if (spec == null || !spec.isFunc) return
      ((MFunc)spec.func).setThunk(thunk)
    }
  }
}

