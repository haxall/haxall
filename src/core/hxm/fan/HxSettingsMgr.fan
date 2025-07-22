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
  Dict extRead(Str name)
  {
    read(extId(name))
  }

  ** Update settings for given ext
  Void extUpdate(HxExtSpi spi, Diff diff)
  {
    // TODO: this is not persisting yet...
    oldDict := spi.settings
    newDict := Etc.dictMerge(oldDict, checkDiff(diff).changes)
    spi.update(newDict)
  }

  ** Map ext to setting rec id
  Ref extId(Str name) { Ref("ext.$name") }


  ** Only standard update diffs can be used with settings manager
  private Diff checkDiff(Diff d)
  {
    if (d.isAdd)       throw DiffErr("Cannot use add diff")
    if (d.isRemove)    throw DiffErr("Cannot use remove diff")
    if (d.isTransient) throw DiffErr("Cannot use transient diff")
    return d
  }

  ** Read and if not found synthetize
  private Dict read(Ref id)
  {
    rec := db.readById(id, false)
    if (rec != null) return rec
    return Etc.dict2("id", id, "mod", DateTime.defVal)
  }

}

