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
** Implementation of DataType wrapped by XetoType
**
@Js
internal const final class MType : MSpec
{
  new make(FileLoc loc, XetoLib lib, Str qname, Str name, XetoType? base, XetoType self, Dict meta, Dict metaOwn, MSlots slots, MSlots slotsOwn, Int flags)
    : super(loc, lib, name, base, self, meta, metaOwn, slots, slotsOwn, flags)
  {
    this.lib   = lib
    this.qname = qname
    this.type  = self
  }

  const override XetoLib lib

  const override Str qname

  override DataSpec spec() { env.sys.type }

  override Bool isType() { true }

  override Str toStr() { qname }
}

**************************************************************************
** XetoType
**************************************************************************

**
** XetoType is the referential proxy for MType
**
@Js
internal const class XetoType : XetoSpec, DataType
{
  new make() : super() {}

  override DataLib lib() { (DataLib)m.parent }

}