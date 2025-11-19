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
  new make(MSpecInit init) : super(init)
  {
    this.lib   = init.lib
    this.qname = init.qname
    this.id    = Ref(qname, null)
  }

  const override XetoLib lib

  const override Str qname

  const override Ref id

  override SpecFlavor flavor() { SpecFlavor.mixIn }

  override Str toStr() { qname }
}

