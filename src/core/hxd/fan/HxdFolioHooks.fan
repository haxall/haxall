//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Jun 2021  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using hx
using hxm

**
** Haxall daemon hooks into the Folio database
**
const class HxdFolioHooks : FolioHooks
{
  ** Constructor
  new make(HxProj rt) { this.rt = rt; this.db = rt.db }

  ** Parent runtime instance
  const HxProj rt

  ** Parent database instance
  const Folio db

  ** Xeto namespace is available
  override LibNamespace? ns(Bool checked := true) { rt.ns }

  ** Def namespace is available
  override DefNamespace? defs(Bool checked := true) { rt.defs }

  ** Callback before diff is committed during verify
  ** phase. An exception will cancel entire commit.
  ** Pass through FolioContext.commitInfo if available.
  override Void preCommit(FolioCommitEvent e)
  {
    diff := e.diff

    if (diff.isUpdate)
    {
      // cannot trash projMeta
      if (diff.id == rt.meta.id && diff.changes.has("trash")) throw CommitErr("Cannot trash projMeta rec")
    }
    else if (diff.isRemove)
    {
      rec := db.readById(diff.id, false) ?: Etc.emptyDict

      // cannot directly remove a library
      if (rec.has("ext") && !diff.isBypassRestricted) throw CommitErr("Must use libRemove to remove lib rec")

      // cannot remove projMeta ever
      if (diff.id == rt.meta.id) throw CommitErr("Cannot remove projMeta rec")
    }
  }

  ** Callback after diff has been committed.
  ** Pass through FolioContext.commitInfo if available.
  override Void postCommit(FolioCommitEvent e)
  {
    diff := e.diff

    // the only transient hook might be to fire a curVal
    // observation; otherwise short circut all other code
    if (diff.isTransient)
    {
// TODO
obs := (HxdObsService)rt.obs
//      if (diff.isCurVal) rt.obs.curVal(diff)
      return
    }

    user := e.cxInfo as HxUser

    if (diff.isUpdate)
    {
      newRec := diff.newRec
      libName := newRec["ext"] as Str
      if (libName != null)
      {
        lib := rt.exts.get(libName, false)
        if (lib != null) ((MExtSpi)lib.spi).update(newRec)
      }

      if (diff.id == rt.meta.id)
      {
echo("TODO: metaRef")
//        rt.metaRef.val = diff.newRec
      }
    }

    if (diff.getOld("def") != null || diff.getNew("def") != null)
    {
//      rt.nsOverlayRecompile
    }

// TODO
obs := (HxdObsService)rt.obs
    obs.commit(diff, user)
  }

  ** Callback after his write.  Result is same dict returned from future.
  override Void postHisWrite(FolioHisEvent e)
  {
// TODO
obs := (HxdObsService)rt.obs
    obs.hisWrite(e.rec, e.result, e.cxInfo as HxUser)
  }
}

