//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Dec 2024  Brian Frank  Creation
//

using util
using xeto

**
** Implementation of top-level meta spec
**
@Js
const final class MMetaSpec : MSpec
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

  override SpecFlavor flavor() { SpecFlavor.meta }

  override Str toStr() { qname }
}

