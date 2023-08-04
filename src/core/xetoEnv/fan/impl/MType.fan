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
  new make(FileLoc loc, XetoLib lib, Int qnameCode, Int nameCode, XetoType? base, XetoType self, Dict meta, Dict metaOwn, MSlots slots, MSlots slotsOwn, Int flags, SpecFactory factory)
    : super(loc, lib.env, null, nameCode, base, self, meta, metaOwn, slots, slotsOwn, flags)
  {
    this.lib       = lib
    this.qnameCode = qnameCode
    this.qname     = lib.env.names.toName(qnameCode)
    this.type      = self
    this.factory   = factory
  }

  const override XetoLib lib

  const Int qnameCode

  const override Str qname

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