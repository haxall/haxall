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
  new make(MSpecInit init) : super(init)
  {
    this.lib   = init.lib
    this.qname = init.qname
    this.id    = Ref(qname, null)
  }

  const override XetoLib lib

  const override Str qname

  const override Ref id

  override SpecFlavor flavor() { SpecFlavor.global }

  override Str toStr() { qname }
}

