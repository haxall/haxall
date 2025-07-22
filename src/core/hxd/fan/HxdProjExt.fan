//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Jul 2025  Brian Frank  Creation
//

using concurrent
using web
using util
using xeto
using haystack
using folio
using hx
using hxm

**
** Haxall daemon simple implementation for required project extension
**
const class HxdProjExt : ExtObj, IProjExt
{

  override Proj? get(Obj id, Bool checked := true)
  {
    name := id as Str ?: HxUtil.projIdToName(id)
    if (name == proj.name) return proj
    if (checked) throw UnknownProjErr(name)
    return null
  }

  override Proj[] list() { Proj#.emptyList }

}

