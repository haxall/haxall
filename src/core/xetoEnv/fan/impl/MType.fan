//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Feb 2023  Brian Frank  Creation
//

using util
using xeto

**
** Implementation of top-level data spec
**
@Js
const final class MType : MSpec
{
  new make(FileLoc loc, XetoEnv env, XetoLib lib, Str qname, Int nameCode, XetoType? base, XetoType self, MNameDict meta, MNameDict metaOwn, MSlots slots, MSlots slotsOwn, Int flags, SpecFactory factory)
    : super(loc, env, null, nameCode, base, self, meta, metaOwn, slots, slotsOwn, flags)
  {
    this.lib       = lib
    this.qname     = qname
    this.id        = haystack::Ref(qname, null)
    this.type      = self
    this.factory   = factory
  }

  const override XetoLib lib

  const override Str qname

  const override haystack::Ref id

  override Spec spec() { env.sys.type }

  override Bool isType() { true }

  override const SpecFactory factory

  override Str toStr() { qname }
}

**************************************************************************
** XetoType
**************************************************************************

**
** XetoType is the referential proxy for MType
**
@Js
const class XetoType : XetoSpec
{
  new make() : super() {}
}