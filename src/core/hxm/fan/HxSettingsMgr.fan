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
  new make(HxRuntime rt)
  {
    this.rt = rt
  }

  const HxRuntime rt

  Folio db() { rt.db }

//////////////////////////////////////////////////////////////////////////
// Runtime meta
//////////////////////////////////////////////////////////////////////////

  ** Update rntime meta
  Void metaUpdate(Obj changes)
  {
    diff := Diff(rt.meta, toUpdateChanges(changes), Diff.bypassRestricted)
    newRec := db.commit(diff).newRec
    rt.metaRef.val = HxMeta(rt, newRec)
  }

//////////////////////////////////////////////////////////////////////////
// Ext Settings
//////////////////////////////////////////////////////////////////////////

  ** Read lib record by name
  Dict extRead(Str name)
  {
    db.read(Filter.eq("name", name).and(Filter.eq("rt", "lib")), false) ?: Etc.dict0
  }

  ** Update settings for given ext
  Void extUpdate(HxExtSpi spi, Obj changes)
  {
    name := spi.name
    curRec := extRead(name)
    dict := toUpdateChanges(changes)
    Dict? newRec
    if (curRec.missing("id"))
    {
      // in the case boot system exts we need to create the record
      add := Etc.dictMerge(dict, ["rt":"lib", "name":name])
      newRec = db.commit(Diff(null, add, Diff.add.or(Diff.bypassRestricted))).newRec
    }
    else
    {
      // update existing record
      newRec = db.commit(Diff(curRec, dict, Diff.bypassRestricted)).newRec
    }
    spi.update(newRec)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

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
    if (dict == null) throw DiffErr("Invalid changes type [$changes.typeof]")
    if (dict.has("rt")) throw DiffErr("Cannot pass 'rt' tag")
    if (dict.has("name")) throw DiffErr("Cannot pass 'name' tag")
    return dict
  }

}

