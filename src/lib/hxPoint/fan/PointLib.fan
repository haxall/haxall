//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Jul 2012  Brian Frank  Creation
//

using concurrent
using haystack
using obs
using hx

**
** Point historization and writable support
**
const class PointLib : HxLib
{
  Void refreshEnumDefs()
  {
    Dict? enumMeta := null
    enumMetaId := enums.meta["id"] as Ref
    if (enumMetaId != null) enumMeta = rt.db.readById(enumMetaId, false)
    if (enumMeta != null && enumMeta.missing("enumMeta")) enumMeta = null
    if (enumMeta != null && enumMeta.has("trash")) enumMeta = null
    if (enumMeta == null) enumMeta = rt.db.read("enumMeta", false)
    if (enumMeta == null) enumMeta = Etc.emptyDict
    enums.updateMeta(enumMeta)
  }

  internal const EnumDefs enums := EnumDefs(log)
}

