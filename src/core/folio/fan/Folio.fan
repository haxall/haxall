//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Oct 2015  Brian Frank  Creation
//

using concurrent
using xeto
using haystack

**
** Folio database
**
abstract const class Folio
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Sub-class constructor
  new make(FolioConfig config)
  {
    this.name     = config.name
    this.config   = config
    this.log      = config.log
    this.dir      = config.dir
    this.idPrefix = config.idPrefix
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Name of this database
  const Str name

  ** Configuration used to init database
  const FolioConfig config

  ** Logging for this database
  const Log log

  ** Home directory for this database
  const File dir

  ** Ref prefix to make internal refs absolute (includes trailing colon)
  @NoDoc const Str? idPrefix

  ** Block until all pending writes have been processed and written to disk
  @NoDoc virtual This sync(Duration? timeout := null, Str? mgr := null) { this }

  ** Get storage for passwords and other secrets
  abstract PasswordStore passwords()

  ** Current persistent version as incrementing counter
  @NoDoc abstract Int curVer()

  ** Callback hooks
  @NoDoc FolioHooks hooks
  {
    get { hooksRef.val }
    set
    {
      if (hooksRef.val isnot NilHooks) throw Err("Cannot modify hooks more than once")
      hooksRef.val = it
    }
  }
  private const AtomicRef hooksRef := AtomicRef(NilHooks())

  ** Backup APIs
  abstract FolioBackup backup()

  ** History storage APIs
  @NoDoc abstract FolioHis his()

  ** File storage APIs
  @NoDoc abstract FolioFile file()

//////////////////////////////////////////////////////////////////////////
// Modes (Flush, Close)
//////////////////////////////////////////////////////////////////////////

  ** Configure store flush method:
  **   - "fsync": fsync after every write - slow but safest (default)
  **   - "nosync": do nothing after every write - fast but no safety
  @NoDoc abstract Str flushMode

  ** Flush any dirty files to disk using fsync
  @NoDoc abstract Void flush()

  ** Return if database is closed
  @NoDoc Bool isClosed() { closedRef.val }
  private const AtomicBool closedRef := AtomicBool(false)

  ** Close the database synchronously (block until closed)
  Void close(Duration? timeout := null)
  {
    closeAsync.getRes(timeout)
  }

  ** Close the database asynchronously and return future
  FolioFuture closeAsync()
  {
    if (closedRef.getAndSet(true))
      return FolioFuture.makeSync(CountFolioRes(0))
    else
      return doCloseAsync
  }

  ** Return if we can read
  @NoDoc Bool canRead() { !isClosed }

  ** Return if we can write
  @NoDoc Bool canWrite() { !isClosed && !config.isReplica }

  ** Verify database is in a valid read mode
  @NoDoc This checkRead()
  {
    if (isClosed) throw ShutdownErr("Cannot read, folio is closed")
    return this
  }

  ** Verify database is in a valid write mode
  @NoDoc This checkWrite()
  {
    if (isClosed) throw ShutdownErr("Cannot write, folio is closed")
    if (config.isReplica) throw ReadonlyReplicaErr("Cannot write, folio is replica")
    return this
  }

  ** Subclass implementation of closeAsync
  @NoDoc protected abstract FolioFuture doCloseAsync()

//////////////////////////////////////////////////////////////////////////
// Reads
//////////////////////////////////////////////////////////////////////////

  ** Read underlying record used for additional rec based features like watches
  ** If checked is true, throw [UnknownRecErr] if the rec isn't found, or
  ** [PermissionErr] if there aren't permissions to read it.
  @NoDoc FolioRec? readRecById(Ref id, Bool checked := true)
  {
    // NOTE: do not route through readRecsById to keep this path fast!
    rec := checkRead.doReadRecByIdRaw(id)

    // do not return trashed recs
    if (rec != null && rec.isTrash) rec = null
    if (rec == null)
    {
      if (checked) throw UnknownRecErr(id.toZinc)
      return null
    }

    cx := FolioContext.curFolio(false)
    if (cx != null && !cx.canRead(rec.dict))
    {
      if (checked) throw PermissionErr("Cannot read: ${id.toZinc}")
      return null
    }
    return rec
  }

  @NoDoc FolioRec?[] readRecsById(Ref[] ids, Bool checked := true)
  {
    doReadRecsById(ids, false).recs(checked)
  }

  private FolioFuture doReadRecsById(Ref[] ids, Bool trash)
  {
    recs     := checkRead.doReadRecsByIdRaw(ids)
    cx       := FolioContext.curFolio(false)
    denied   := false
    Err? err := null
    ids.each |id, i|
    {
      rec := recs[i]

      // do not return trash recs
      if (rec != null && rec.isTrash && !trash) recs[i] = rec = null

      if (rec == null)
      {
        // only the first missing rec is reported, but permission errs get priority
        if (err == null) err = UnknownRecErr(id.toZinc)
      }
      else if (cx != null && !cx.canRead(rec.dict))
      {
        recs[i] = null

        // a permission error always wins over a missing rec
        if (!denied) { denied = true; err = PermissionErr("Cannot read: ${id.toZinc}") }
      }
    }
    return FolioFuture.makeSync(ReadFolioRecsRes(err, recs))
  }

  ** Convenience for [readByIds] with single id.
  Dict? readById(Ref id, Bool checked := true)
  {
    readRecById(id, checked)?.dict
  }

  ** Read a list of records by ids into a grid.  The rows in the
  ** result correspond by index to the ids list.  If checked is true,
  ** then every id must be found in the project or UnknownRecErr
  ** is thrown.  If checked is false, then an unknown record is
  ** returned as a row with every column set to null (including
  ** the `id` tag).
  Grid readByIds(Ref[] ids, Bool checked := true)
  {
    doReadRecsById(ids, false).grid(checked)
  }

  ** Read a list of records by id.  The resulting list matches
  ** the list of ids by index (null if record not found).
  Dict?[] readByIdsList(Ref[] ids, Bool checked := true)
  {
    doReadRecsById(ids, false).dicts(checked)
  }

  ** Return the number of records which match given [filter](ph.doc::Filters).
  ** This method supports the same options as [readAll].
  Int readCount(Filter filter, Dict? opts := null)
  {
    checkRead
    sink := FolioReadSink(FolioContext.curFolio(false), opts) |rec->Obj?| { return null }
    if (sink.limit <= 0) return 0

    // check if we can delegate to subtype for optimized count
    if (sink.canFastCount) return doReadCount(filter)

    stream(filter, false, sink)
    return sink.count
  }

  ** Find the first record which matches the given [filter](ph.doc::Filters).
  ** Throw UnknownRecErr or return null based on checked flag.
  Dict? read(Filter filter, Bool checked := true)
  {
    readAllSync(filter, optsLimit1, false).dict(checked)
  }

  ** Match all the records against a [filter](ph.doc::Filters) and
  ** return as grid.
  **
  ** Options:
  **   - limit: max number of recs to read
  **   - search: search string to apply in addition to filter
  **   - sort: marker tag to sort recs by dis string
  **   - gridMeta: Dict to use for grid meta
  Grid readAll(Filter filter, Dict? opts := null)
  {
    readAllSync(filter, opts, false).gridWithOpts(opts, false)
  }

  ** Match all the records against a [filter](ph.doc::Filters) and return
  ** as list.  This method uses same semantics and options as [readAll].
  Dict[] readAllList(Filter filter, Dict? opts := null)
  {
    readAllSync(filter, opts, false).dicts
  }

  ** Match all the records in the trash against a [filter](ph.doc::Filters)
  ** and return as grid.  Only records with the `trash` tag are returned;
  ** every other read method excludes them.  Uses the same options as [readAll].
  @NoDoc Grid readTrash(Filter filter, Dict? opts := null)
  {
    readAllSync(filter, opts, true).gridWithOpts(opts, false)
  }

  ** Read by id whether rec is in trash or not
  @NoDoc Dict? readByIdTrash(Ref? id, Bool checked := true)
  {
    if (id == null)
    {
      if (checked) throw UnknownRecErr("null")
      return null
    }
    return doReadRecsById([id], true).dict(checked)
  }

  ** Read all records matching filter.
  @NoDoc Obj? readAllEach(Filter filter, Dict? opts, |Dict| f)
  {
    readAllEachWhile(filter, opts) |x| { f(x); return null }
  }

  ** Read all records matching filter until callback returns non-null.
  @NoDoc Obj? readAllEachWhile(Filter filter, Dict? opts, |Dict->Obj?| f)
  {
    checkRead
    sink := FolioReadSink(FolioContext.curFolio(false), opts, f)
    if (sink.limit <= 0) return null
    stream(filter, false, sink)
    return sink.result
  }

  ** Stream recs matching filter to the sink from the live or trash domain.
  ** The value returned by the hook is _not_ the result of the read - it may
  ** be the sink's internal break sentinel - so callers use `FolioReadSink.result`.
  private Void stream(Filter filter, Bool trash, FolioReadSink sink)
  {
    if (trash) doReadTrashEachWhile(filter, sink)
    else doReadAllEachWhile(filter, sink)
  }

  ** Read all recs matching filter as a sync future
  private FolioFuture readAllSync(Filter filter, Dict? opts, Bool trash)
  {
    checkRead
    acc := Dict[,]
    sink := FolioReadSink.makeAccumulate(FolioContext.curFolio(false), opts, acc)
    if (sink.limit > 0) stream(filter, trash, sink)
    if (sink.sort) acc = Etc.sortDictsByDis(acc)
    return FolioFuture.makeSync(ReadFolioRes(filter, false, acc))
  }

  ** Options constant for {limit:1}
  private const static Dict optsLimit1 := Etc.dict1("limit", Number(1))

  ** Read only persistent tags for given rec id
  @NoDoc Dict? readByIdPersistentTags(Ref id, Bool checked := true)
  {
    doReadRecsById([id], false).rec(checked)?.persistent
  }

  ** Read only transient only tags for given rec id
  @NoDoc Dict? readByIdTransientTags(Ref id, Bool checked := true)
  {
    doReadRecsById([id], false).rec(checked)?.transient
  }

  ** Intern the given ref to its canonical representation
  @NoDoc virtual Ref internRef(Ref id)
  {
    rec := readById(id, false)
    if (rec != null) return rec.id
    return id
  }

  ** Read a live or trashed rec by id.
  ** Must resolve relative refs against `idPrefix`.
  ** - Never check permissions
  @NoDoc protected abstract FolioRec? doReadRecByIdRaw(Ref id)

  ** Read a list of live or trashed recs by id.
  ** The default implementation maps [doReadRecByIdRaw].
  ** Must resolve relative refs against `idPrefix`.
  ** - Never check permissions
  @NoDoc protected virtual FolioRec?[] doReadRecsByIdRaw(Ref[] ids)
  {
    ids.map |id->FolioRec?| { doReadRecByIdRaw(id) }
  }

  ** Subclass implementation to stream every rec matching filter
  ** to the sink until [FolioReadSink.accept] returns non-null, in which
  ** case return that value.
  ** - Never read recs in the trash
  ** - Never check permissions
  @NoDoc protected abstract Obj? doReadAllEachWhile(Filter filter, FolioReadSink sink)

  ** Subclass implementation to stream every rec in the trash matching filter
  ** - Never check permissions
  @NoDoc protected abstract Obj? doReadTrashEachWhile(Filter filter, FolioReadSink sink)

  ** Subclass hook to count matching the filter. The base class only calls this
  ** when no context is installed and no options need to be applied, so subclasses
  ** are free to optimize.
  ** - Never count recs in the trash
  ** - Never check permissions
  @NoDoc protected virtual Int doReadCount(Filter filter)
  {
    sink := FolioReadSink.makeCount
    doReadAllEachWhile(filter, sink)
    return sink.count
  }

//////////////////////////////////////////////////////////////////////////
// Commits
//////////////////////////////////////////////////////////////////////////

  ** Convenience for [commitAll] with a single diff.
  Diff commit(Diff diff)
  {
    doCommitAllSync(checkCommits([diff]), cxCommitInfo).diff
  }

  ** Apply a list of diffs to the database in batch.  Either all the
  ** changes are successfully applied, or else none of them are applied
  ** and an exception is raised.  Return updated Diffs which encapsulate
  ** both the old and new version of each record.
  **
  ** If any of the records have been modified since they were read
  ** for the given change set then ConcurrentChangeErr is thrown
  ** unless `Diff.force` configured.
  Diff[] commitAll(Diff[] diffs)
  {
    doCommitAllSync(checkCommits(diffs), cxCommitInfo).diffs
  }

  ** Convenience for [commitAllAsync] with a single diff.
  FolioFuture commitAsync(Diff diff)
  {
    doCommitAllAsync(checkCommits([diff]), cxCommitInfo)
  }

  ** Commit a list of diffs to the database asynchronously.
  FolioFuture commitAllAsync(Diff[] diffs)
  {
    doCommitAllAsync(checkCommits(diffs), cxCommitInfo)
  }

  ** Remove all records with the trash tag
  @NoDoc FolioFuture commitRemoveTrashAsync()
  {
    recs := readAllSync(Filter.has("trash"), null, true).dicts
    diffs := recs.map |rec->Diff| { Diff(rec, null, Diff.remove.or(Diff.force)) }
    return commitAllAsync(diffs)
  }

  ** Subclass implementation of commitAll (default routes to doCommitAllAsync)
  ** Diffs must be checked using [checkCommits] before calling this.
  @NoDoc virtual protected FolioFuture doCommitAllSync(Diff[] diffs, Obj? cxInfo)
  {
    doCommitAllAsync(diffs, cxInfo)
  }

  ** Subclass implementation of commitAllAsync
  @NoDoc abstract protected FolioFuture doCommitAllAsync(Diff[] diffs, Obj? cxInfo)

  ** Context commit info to pass back to FolioHooks
  private Obj? cxCommitInfo() { FolioContext.curFolio(false)?.commitInfo }

  ** Verify the database is writable, validate the diffs, and check write
  ** permission for each one. Throws DiffErr if the diffs are invalid, or
  ** PermissionErr on the first diff which fails its check. If no context
  ** is installed then all diffs are allowed. Returns the diffs (unmodified)
  ** for convenience.
  private Diff[] checkCommits(Diff[] diffs)
  {
    checkWrite
    FolioUtil.checkDiffs(diffs)

    cx := FolioContext.curFolio(false)
    if (cx == null) return diffs

    // old rec is null for adds and for recs which do not exist; the raw
    // read includes the trash since a commit may untrash a rec
    oldRecs := doReadRecsByIdRaw(diffs.map |diff->Ref| { diff.id })
    diffs.each |diff, i|
    {
      // canWrite assumes canRead already verified; the raw read above
      // bypasses security so we must check read access here ourselves
      old := oldRecs[i]?.dict
      if (old != null && !cx.canRead(old)) throw PermissionErr("Cannot write: $diff.id.toZinc")
      if (!cx.canWrite(FolioWrite.makeCommit(old, diff)))
        throw PermissionErr("Cannot write: $diff.id.toZinc")
    }
    return diffs
  }
}
