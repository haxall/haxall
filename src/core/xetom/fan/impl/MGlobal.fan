//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Dec 2023  Brian Frank  Creation
//

using util
using xeto

**
** Implementation of top-level global slot spec
**
@Js
const final class MGlobal : MSpec
{
  new make(FileLoc loc, XetoLib lib, Str qname, Str name, XetoSpec? base, XetoSpec self, MNameDict meta, MNameDict metaOwn, MSlots slots, MSlots slotsOwn, Int flags, MSpecArgs args)
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

  override SpecFlavor flavor() { SpecFlavor.global }

  override Str toStr() { qname }
}

