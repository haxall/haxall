//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jun 2019  Brian Frank  Creation
//

using concurrent
using haystack

**
** MCell models one cell of a MComp
**
@Js
internal class MCell
{
  new make(MCellDef def)
  {
    this.def = def
    this.val = def.defVal
  }

  const MCellDef def

  Str name() { def.name }

  Obj? get() { val }

  Void set(Obj? val)
  {
    if (def.ro) throw ReadonlyErr("Cannot set readonly cell: $def")
    this.val = val
  }

  Void recomputed(Obj? val)
  {
    this.val = val
  }

  private Obj? val
}





