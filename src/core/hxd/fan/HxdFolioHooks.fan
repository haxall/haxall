//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Jun 2021  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hx

**
** Haxall daemon hooks into the Folio database
**
const class HxdFolioHooks : FolioHooks
{
  ** Constructor
  new make(HxdRuntime rt) { this.rt = rt; this.db = rt.db }

  ** Parent runtime instance
  const HxdRuntime rt

  ** Parent database instance
  const Folio db

  ** Def namespace is available
  override Namespace? ns(Bool checked := true) { rt.ns }

  ** Callback before diff is committed during verify
  ** phase. An exception will cancel entire commit.
  ** Pass through FolioContext.commitInfo if available.
  override Void preCommit(Diff diff, Obj? cxInfo)
  {
    if (diff.isRemove && !diff.isBypassRestricted)
    {
      rec := db.readById(diff.id, false) ?: Etc.emptyDict
      if (rec.has("hxLib")) throw CommitErr("Must use libRemove to remove hxLib rec")
    }
  }

  ** Callback after diff has been committed.
  ** Pass through FolioContext.commitInfo if available.
  override Void postCommit(Diff diff, Obj? cxInfo)
  {
    if (diff.getOld("def") != null || diff.getNew("def") != null)
    {
      rt.nsOverlayRecompile
    }
  }
}