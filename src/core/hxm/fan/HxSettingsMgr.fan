//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Jul 2025  Brian Frank  Creation
//

using xeto
using haystack
using hx
using folio

**
** Haxall management of proj/ext settings using a backing trio file
**
const class HxSettingsMgr
{
  new make(HxProj proj, HxBoot boot)
  {
    this.proj = proj
    this.db   = boot.initSettingsFolio
  }

  const HxProj proj
  const Folio db

  ** Read settings for given ext library name or return empty dict
  Dict readExt(Str name)
  {
    read(extId(name))
  }

  ** Map ext to setting rec id
  Ref extId(Str name) { Ref("ext.$name") }

  ** Read and if not found synthetize
  private Dict read(Ref id)
  {
    rec := db.readById(id, false)
    if (rec != null) return rec
    return Etc.dict2("id", id, "mod", DateTime.defVal)
  }

}

