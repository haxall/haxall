//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Jul 2025  Brian Frank  Creation
//

using xeto
using haystack
using folio
using hx
using xetom
using xetoc

**
** Namespace implementation
**
const class HxNamespace : MNamespace, Namespace
{
  internal new make(HxRuntime rt, MEnv env, LibVersion[] vers, Dict opts) : super(env, vers, opts)
  {
    this.rt = rt
  }

  const HxRuntime rt

  override Dict[] readCompanionLibRecs()
  {
    rt.db.readAllList(Filter.eq("rt", "spec").or(Filter.eq("rt", "instance")))
  }
}

