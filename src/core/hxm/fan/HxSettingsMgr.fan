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

//////////////////////////////////////////////////////////////////////////
// Proj meta
//////////////////////////////////////////////////////////////////////////

  ** Setting id for projMeta
  static const Ref projMetaId := Ref("projMeta")

  ** Initialize projMeta
  Dict projMetaInit(HxBoot boot)
  {
    init(projMetaId, Etc.dictFromMap(boot.createProjMeta))

    cur := db.readById(projMetaId, false)

    // make sure we init/update cur version and projMeta marker
    version := boot.sysInfoVersion.toStr
    required := Etc.dict2("projMeta", Marker.val, "version", version)
    if (cur == null)
    {
      cur = db.commit(Diff(null, required)).newRec
    }
    else if (cur["version"] != version || cur["projMeta"] != Marker.val)
    {
      cur = db.commit(Diff(cur, required, Diff.bypassRestricted)).newRec
    }
    return cur
  }

  ** Update projMeta
  Void projMetaUpdate(Obj changes)
  {
    proj.metaRef.val = update(projMetaId, changes)
  }

//////////////////////////////////////////////////////////////////////////
// Exts
//////////////////////////////////////////////////////////////////////////

  ** Map ext to setting rec id
  Ref extId(Str name) { Ref("ext.$name") }

  ** Read settings for given ext library name or return empty dict
  Dict extRead(Str name)
  {
    read(extId(name))
  }

  ** Update settings for given ext
  Void extUpdate(HxExtSpi spi, Obj changes)
  {
    spi.update(update(extId(spi.name), changes))
  }

  ** Initialize settings before we create ExtSpi
  Void extInit(Str name, Dict settings)
  {
    init(extId(name), settings)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Read and if not found synthetize
  private Dict read(Ref id)
  {
    rec := db.readById(id, false)
    if (rec != null) return rec
    return Etc.dict2("id", id, "mod", DateTime.defVal)
  }

  ** Update settings and return new dict
  private Dict update(Ref id, Obj changes)
  {
    cur  := db.readById(id, false)
    diff := toUpdateDiff(id, cur, changes)
    return write(diff)
  }

  ** Only standard update diffs can be used with settings manager
  private Diff toUpdateDiff(Ref id, Dict? cur, Obj changes)
  {
    diff := changes as Diff
    if (diff != null)
    {
      if (diff.isAdd)       throw DiffErr("Cannot use add diff")
      if (diff.isRemove)    throw DiffErr("Cannot use remove diff")
      if (diff.isTransient) throw DiffErr("Cannot use transient diff")
      return cur == null ? Diff.makeAdd(diff.changes, id) : diff
    }

    dict := changes as Dict
    if (dict == null && changes is Map) dict = Etc.dictFromMap(changes)
    if (dict == null) throw ArgErr("Invalid changes type [$changes.typeof]")

    return cur == null ? Diff.makeAdd(dict, id) : Diff.make(cur, changes)
  }

  ** Initialize settings
  private Dict init(Ref id, Dict settings)
  {
    old := db.readById(id, false)
    if (old != null) write(Diff(old, null, Diff.remove))
    return write(Diff.makeAdd(settings, id))
  }

  ** Write
  private Dict write(Diff diff)
  {
    db.commit(diff).newRec
  }

}

