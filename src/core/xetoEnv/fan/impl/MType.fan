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
** Implementation of top-level type spec
**
@Js
const final class MType : MSpec
{
  new make(FileLoc loc, XetoEnv env, XetoLib lib, Str qname, Int nameCode, XetoType? base, XetoType self, MNameDict meta, MNameDict metaOwn, MSlots slots, MSlots slotsOwn, Int flags, MSpecArgs args, SpecFactory factory)
    : super(loc, env, null, nameCode, base, self, meta, metaOwn, slots, slotsOwn, flags, args)
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

  override Bool isType() { true }

  override const SpecFactory factory

  override MEnum enum()
  {
    if (enumRef != null) return enumRef
    if (base !== env.sys.enum) return super.enum
    MType#enumRef->setConst(this, MEnum.init(this))
    return enumRef
  }
  private const MEnum? enumRef

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