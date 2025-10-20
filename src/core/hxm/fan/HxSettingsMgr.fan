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
using hxUtil
using folio

**
** Haxall management of proj/ext settings using a backing trio file
**
const class HxSettingsMgr
{
  new make(HxRuntime rt, HxBoot boot)
  {
    this.rt = rt
    this.db = TextBaseRecs(rt.tb, "settings.trio")
  }

  const HxRuntime rt
  const TextBaseRecs db

//////////////////////////////////////////////////////////////////////////
// Proj meta
//////////////////////////////////////////////////////////////////////////

/*
  ** Setting id for projMeta
  static const Ref projMetaId := Ref("projMeta")

  ** Initialize projMeta
  Dict projMetaInit(HxBoot boot)
  {
    // read current
    id := projMetaId
    cur := db.readById(id, false)

    // make sure we init/update cur version and projMeta marker
    version := boot.sysInfoVersion.toStr
    if (cur == null || cur["projMeta"] != Marker.val || cur["version"] != version)
    {
      cur = db.update(id, Etc.dict2("projMeta", Marker.val, "version", version))
    }

    cur.id.disVal = cur.dis
    return cur
  }
*/

  ** Update projMeta
  Void projMetaUpdate(Obj changes)
  {
    diff := Diff(rt.meta, toUpdateChanges(changes), Diff.bypassRestricted)
    newRec := rt.db.commit(diff).newRec
    rt.metaRef.val = newRec
  }

//////////////////////////////////////////////////////////////////////////
// Exts
//////////////////////////////////////////////////////////////////////////

  ** Map ext to setting rec id
  static Ref extId(Str name) { Ref("ext.$name") }

  ** Read settings for given ext library name or return empty dict
  Dict extRead(Str name)
  {
    read(extId(name))
  }

  ** Update settings for given ext
  Void extUpdate(HxExtSpi spi, Obj changes, Bool reset)
  {
    id := extId(spi.name)
    newSettings :=  reset ? init(id, changes) : update(id, changes)
    spi.update(newSettings)
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
    write(id, toUpdateChanges(changes))
  }

  ** Only standard update diffs can be used with settings manager
  private Dict toUpdateChanges(Obj changes)
  {
    dict := changes as Dict
    diff := changes as Diff
    if (diff != null)
    {
      if (diff.isAdd)       throw DiffErr("Cannot use add diff")
      if (diff.isRemove)    throw DiffErr("Cannot use remove diff")
      if (diff.isTransient) throw DiffErr("Cannot use transient diff")
      dict = diff.changes
    }

    if (dict == null && changes is Map) dict = Etc.dictFromMap(changes)
    if (dict == null) throw ArgErr("Invalid changes type [$changes.typeof]")
    if (dict.has("rt")) throw ArgErr("Cannot pass 'rt' tag")
    if (dict.has("name")) throw ArgErr("Cannot pass 'name' tag")
    return dict
  }

  ** Initialize settings
  private Dict init(Ref id, Dict settings)
  {
    old := db.readById(id, false)
    if (old != null) db.remove(id)
    return write(id, settings)
  }

  ** Write
  private Dict write(Ref id, Dict changes)
  {
    db.update(id, changes)
  }

}

