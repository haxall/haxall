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
  @NoDoc FolioRec? readRecById(Ref id, Bool checked := true)
  {
    doReadRecById(id, checked, false)
  }

  ** Apply trash exclusion and permission checking to the raw by-id read.
  ** If trash is true then recs in the trash are returned too.
  private FolioRec? doReadRecById(Ref id, Bool checked, Bool trash)
  {
    rec := checkRead.doReadRecByIdRaw(id)

    // trashed recs are invisible unless trash flag is set
    if (rec != null && rec.isTrash && !trash) rec = null

    if (rec != null)
    {
      cx := FolioContext.curFolio(false)
      if (cx == null || cx.canRead(rec.dict)) return rec
      if (checked) throw UnknownRecErr("Cannot read: $id.toZinc")
    }
    if (checked) throw UnknownRecErr(id.toZinc)
    return null
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
    readByIdsSync(ids).grid(checked)
  }

  ** Read a list of records by id.  The resulting list matches
  ** the list of ids by index (null if record not found).
  Dict?[] readByIdsList(Ref[] ids, Bool checked := true)
  {
    readByIdsSync(ids).dicts(checked)
  }

  ** Apply permission checks to the raw by-id reads and build the error
  ** message. A rec which is missing, in the trash, or which we do not
  ** have permission to read is returned as null.
  private FolioFuture readByIdsSync(Ref[] ids)
  {
    dicts := checkRead.doReadByIdsRaw(ids)
    cx := FolioContext.curFolio(false)
    errMsg := ""
    ids.each |id, i|
    {
      dict := dicts[i]

      // trash recs are invisible
      if (dict != null && dict.has("trash")) dicts[i] = dict = null

      if (dict == null)
      {
        // only the first missing rec is reported
        if (errMsg.isEmpty) errMsg = id.toStr
      }
      else if (cx != null && !cx.canRead(dict))
      {
        // a permission error always wins over a missing rec
        errMsg = "Cannot read: $id.toZinc"
        dicts[i] = null
      }
    }
    return FolioFuture.makeSync(ReadFolioRes(errMsg, !errMsg.isEmpty, dicts))
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
    return doReadRecById(id, checked, true)?.dict
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
    doReadRecById(id, checked, false)?.persistent
  }

  ** Read only transient only tags for given rec id
  @NoDoc Dict? readByIdTransientTags(Ref id, Bool checked := true)
  {
    doReadRecById(id, checked, false)?.transient
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
  @NoDoc protected virtual Dict?[] doReadByIdsRaw(Ref[] ids)
  {
    ids.map |id->Dict?| { doReadRecByIdRaw(id)?.dict }
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
    oldRecs := doReadByIdsRaw(diffs.map |diff->Ref| { diff.id })
    diffs.each |diff, i|
    {
      if (!cx.canWrite(FolioWrite.makeCommit(oldRecs[i], diff)))
        throw PermissionErr("Cannot write: $diff.id.toZinc")
    }
    return diffs
  }
}
