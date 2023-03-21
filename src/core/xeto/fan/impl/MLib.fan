//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jan 2023  Brian Frank  Creation
//

using util
using data

**
** Implementation of DataLib wrapped by XetoLib
**
@Js
internal const final class MLib : MSpec
{
  new make(XetoEnv env, FileLoc loc, Str qname, XetoType libType, DataDict own, MSlots declared)
    : super(loc, null, "", libType, libType, own, declared, 0)
  {
    this.env   = env
    this.qname = qname
  }

  const override XetoEnv env

  const override Str qname

  override DataSpec spec() { env.sys.lib }

  Version version()
  {
    // TODO
    return Version.fromStr(meta->version)
  }

  override Bool isLib() { true }

  override Str toStr() { qname }

}

**************************************************************************
** XetoLib
**************************************************************************

**
** XetoLib is the referential proxy for MLib
**
@Js
internal const class XetoLib : XetoSpec, DataLib
{
  new make() : super() {}

  override Version version() { ml.version }

  const MLib? ml
}

