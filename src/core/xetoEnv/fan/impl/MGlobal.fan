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
  new make(FileLoc loc, XetoEnv env, XetoLib lib, Str qname, Int nameCode, XetoType? base, XetoType self, MNameDict meta, MNameDict metaOwn, MSlots slots, MSlots slotsOwn, Int flags, MSpecArgs args)
    : super(loc, env, null, nameCode, base, self, meta, metaOwn, slots, slotsOwn, flags, args)
  {
    this.lib       = lib
    this.qname     = qname
    this.id        = haystack::Ref(qname, null)
    this.type      = self
  }

  const override XetoLib lib

  const override Str qname

  const override haystack::Ref id

  override Bool isGlobal() { true }

  override Str toStr() { qname }
}

**************************************************************************
** XetoGlobal
**************************************************************************

**
** XetoGlobal is the referential proxy for MGlobal
**
@Js
const class XetoGlobal : XetoSpec
{
  new make() : super() {}
}