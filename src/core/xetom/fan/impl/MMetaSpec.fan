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
  new make(MSpecInit init) : super(init)
  {
    this.lib   = init.lib
    this.qname = init.qname
    this.id    = Ref(qname, null)
  }

  const override XetoLib lib

  const override Str qname

  const override Ref id

  override SpecFlavor flavor() { SpecFlavor.meta }

  override Str toStr() { qname }
}

