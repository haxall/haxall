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
  new make(HxRuntime rt) { this.rt = rt }

  ** Parent runtime instance
  const HxRuntime rt

  ** Xeto namespace is available
  override LibNamespace? ns(Bool checked := true) { rt.ns }

  ** Def namespace is available
  override DefNamespace? defs(Bool checked := true) { rt.defs }

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
      if (diff.isCurVal) rt.obsRef.curVal(diff)
      return
    }

    // fire off tree updates to ion for nav tree rebuild
    if (diff.isTreeUpdate) rt.sys.ion(false)?.updateNavTree(rt)

    // old school def rebuild
    if (diff.getOld("def") != null || diff.getNew("def") != null)
    {
      rt.nsOverlayRecompile
    }

    // fire to observables
    rt.obsRef.commit(diff, user)
  }

  ** Callback after his write.  Result is same dict returned from future.
  override Void postHisWrite(FolioHisEvent e)
  {
    rt.obsRef.hisWrite(e.rec, e.result, e.cxInfo as HxUser)
  }
}

