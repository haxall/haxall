//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Oct 2015  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hxStore

**
** Haxall folio implementation
**
const class HxFolio : Folio
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  **
  ** Open database for given directory.  This method blocks until
  ** database is synchronously loaded into memory.
  **
  static Folio open(FolioConfig config)
  {
    loader := Loader(config)
    loader.load
    return make(loader)
  }

  ** Constructor for open
  private new make(Loader loader) : super(loader.config)
  {
    this.passwords  = PasswordStore.open(dir+`passwords.props`, config)
    this.debug      = DebugMgr(this)
    this.index      = IndexMgr(this, loader)
    this.store      = StoreMgr(this, loader)
    this.disMgr     = DisMgr(this)
    this.stats      = StatsMgr(this)
    this.backup     = BackupMgr(this)
    this.his        = HisMgr(this)
    this.mgrsByName = initMgrsByName
    disMgr.updateAll.get(null)
  }

  private Str:HxFolioMgr initMgrsByName()
  {
    ["debug":   debug,
     "index":   index,
     "store":   store,
     "dis":     disMgr,
     "stats":   stats,
     "backup":  stats]
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Password storage
  const override PasswordStore passwords

  ** In-memory indexing
  internal const IndexMgr index

  ** Persistent storage
  internal const StoreMgr store

  ** Ref.dis manager
  internal const DisMgr disMgr

  ** Debugging manager
  const DebugMgr debug

  ** Statistics manager
  internal const StatsMgr stats

  ** Backup manager
  override const BackupMgr backup

  ** History manager
  override const HisMgr his

  ** Managers by name
  internal const Str:HxFolioMgr mgrsByName

  ** Diagnostics to map to debug::DiagAttr (without dependency)
  FolioDiag[] diags() { stats.diags }

  ** Current version as incrementing counter
  override Int curVer() { store.blobs.ver }

//////////////////////////////////////////////////////////////////////////
// HxFolio Recs
//////////////////////////////////////////////////////////////////////////

  ** Lookup the Rec which wraps the Dict for a given id
  Rec? rec(Ref id, Bool checked := true) { index.rec(id, checked) }

  ** If database has namespace, ensure given ref is absolute
  Ref toAbsRef(Ref ref)
  {
    if (ref.isRel && idPrefix != null) return ref.toAbs(idPrefix)
    return ref
  }

//////////////////////////////////////////////////////////////////////////
// Folio API
//////////////////////////////////////////////////////////////////////////

  override Str flushMode
  {
    get { store.blobs.flushMode }
    set { store.blobs.flushMode = it }
  }

  override Void flush()
  {
    store.blobs.flush
  }

  override This sync(Duration? timeout := null, Str? mgr := null)
  {
    msg := Msg(MsgId.sync)
    if (mgr == null)
      doSync(msg).get(timeout)
    else
      mgrsByName.getChecked(mgr).send(msg).get(timeout)
    return this
  }

  override protected FolioFuture doCloseAsync()
  {
    msg := Msg(MsgId.close)
    return FolioFuture(doSync(msg))
  }

  private Future doSync(Msg msg)
  {
    f := index.send(msg)
    f = store.sendWhenComplete(f, msg)
    return f
  }

  override protected FolioFuture doReadByIds(Ref[] ids)
  {
    cx := FolioContext.curFolio(false)
    errMsg := ""
    dicts := Dict?[,]
    dicts.size = ids.size
    ids.each |id, i|
    {
      rec := index.rec(id, false)
      if (rec != null && !rec.isTrash)
      {
        dict := rec.dict
        if (cx != null && !cx.canRead(dict))
          errMsg = "No read permission: $id.toStr"
        else
          dicts[i] = dict
      }
      else if (errMsg.isEmpty)
      {
        errMsg = id.toStr
      }
    }
    errs := !errMsg.isEmpty
    return FolioFuture(ReadFolioRes(errMsg, errs, dicts))
  }

  override protected FolioFuture doReadAll(Filter filter, Dict? opts)
  {
    if (opts == null) opts = Etc.emptyDict
    cx := FolioContext.curFolio(false)
    dicts := Query(this, filter, opts).collect(cx)
    return FolioFuture(ReadFolioRes(filter, false, dicts))
  }

  override protected Obj? doReadAllEachWhile(Filter filter, Dict? opts, |Dict->Obj?| f)
  {
    if (opts == null) opts = Etc.emptyDict
    cx := FolioContext.curFolio(false)
    return Query(this, filter, opts).eachWhile(cx, f)
  }

  override protected Int doReadCount(Filter filter, Dict? opts)
  {
    if (opts == null) opts = Etc.emptyDict
    cx := FolioContext.curFolio(false)
    return Query(this, filter, opts).count(cx)
  }

  override protected FolioFuture doCommitAllAsync(Diff[] diffs, Obj? cxInfo)
  {
    diffs = diffs.toImmutable

    // check on caller's thread
    FolioUtil.checkDiffs(diffs)
    cx := FolioContext.curFolio(false)
    if (cx != null) diffs.each |diff| { checkCanWrite(cx, diff) }

    // build set of normalized new ids we are adding
    [Ref:Ref]? newIds := null
    diffs.each |diff|
    {
      if (!diff.isAdd) return
      if (newIds == null) newIds = Ref:Ref[:]
      id := toAbsRef(diff.id)
      newIds[id] = id
    }

    // route to index actor thread
    return FolioFuture(index.send(Msg(MsgId.commit, diffs, newIds, cxInfo)))
  }

  private Void checkCanWrite(FolioContext cx, Diff diff)
  {
    id := diff.id
    rec := index.dict(id, false)
    if (rec == null) return
    if (!cx.canWrite(rec)) throw PermissionErr("Cannot write: $id.toCode")
  }

  override Dict? readByIdPersistentTags(Ref id, Bool checked := true)
  {
    rec(id, checked)?.persistent
  }

  override Dict? readByIdTransientTags(Ref id, Bool checked := true)
  {
    rec(id, checked)?.transient
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void debugDump(OutStream out) { debug.dump(out) }

}

