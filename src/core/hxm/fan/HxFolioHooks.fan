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

**
** Haxall project hooks into the Folio database
**
const class HxFolioHooks : FolioHooks
{
  ** Constructor
  new make(HxProj proj) { this.proj = proj }

  ** Parent project instance
  const HxProj proj

  ** Xeto namespace is available
  override LibNamespace? ns(Bool checked := true) { proj.ns }

  ** Def namespace is available
  override DefNamespace? defs(Bool checked := true) { proj.defs }

  ** Callback before diff is committed during verify
  ** phase. An exception will cancel entire commit.
  ** Pass through FolioContext.commitInfo if available.
  override Void preCommit(FolioCommitEvent e) {}


  ** Callback after diff has been committed.
  ** Pass through FolioContext.commitInfo if available.
  override Void postCommit(FolioCommitEvent e)
  {
    diff := e.diff
    user := e.cxInfo as HxUser

    // the only transient hook might be to fire a curVal
    // observation; otherwise short circut all other code
    if (diff.isTransient)
    {
      if (diff.isCurVal) proj.obsRef.curVal(diff)
      return
    }

    if (diff.getOld("def") != null || diff.getNew("def") != null)
    {
      proj.nsOverlayRecompile
    }

    proj.obsRef.commit(diff, user)
  }

  ** Callback after his write.  Result is same dict returned from future.
  override Void postHisWrite(FolioHisEvent e)
  {
    proj.obsRef.hisWrite(e.rec, e.result, e.cxInfo as HxUser)
  }
}

