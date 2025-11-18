//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Dec 2023  Brian Frank  Creation
//  18 Nov 2025  Brian Frank  Refine from original MGlobal
//

using util
using xeto

**
** Implementation of top-level mixin spec
**
@Js
const final class MMixin: MSpec
{
  new make(FileLoc loc, XetoLib lib, Str qname, Str name, XetoSpec? base, XetoSpec self, Dict meta, Dict metaOwn, MSlots slots, MSlots slotsOwn, Int flags, MSpecArgs args)
    : super(loc, null, name, base, self, meta, metaOwn, slots, slotsOwn, flags, args)
  {
    this.lib   = lib
    this.qname = qname
    this.id    = Ref(qname, null)
    this.type  = self
  }

  const override XetoLib lib

  const override Str qname

  const override Ref id

  override SpecFlavor flavor() { SpecFlavor.mixIn }

  override Str toStr() { qname }
}

