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
      return FolioFuture(Future.makeCompletable.complete(CountFolioRes(0)))
    else
      return doCloseAsync
  }

  ** Return if we can read
  @NoDoc Bool isReadable() { !isClosed }

  ** Return if we can write
  @NoDoc Bool isWritable() { !isClosed && !config.isReplica }

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
// Read APIs
//////////////////////////////////////////////////////////////////////////

  ** Read record by id.  If checked is true, throw [haystack::UnknownRecErr]
  ** if not found, or throw [haystack::PermissionErr] if missing read permission
  ** in current context.  Or if checked is false return null in those cases.
  Dict? readById(Ref id, Bool checked := true)
  {
    readRecById(id, checked)?.dict
  }

  ** Read underlying record wrapper by id.  If checked is true, throw
  ** [haystack::UnknownRecErr] if not found, or throw [haystack::PermissionErr]
  ** if missing read permission in current context.  Or if checked is false
  ** return null in those cases.
  @NoDoc FolioRec? readRecById(Ref id, Bool checked := true)
  {
    // NOTE: do not route through readRecsById to keep this path fast!
    FolioIdsReader.checkRec(id, checkRead.doReadRecById(id), checked)
  }

  ** Read a list of records by id.  The resulting list matches the list of
  ** ids by index.  If checked is true, throw [haystack::UnknownRecErr] if
  ** any id is not found, or throw [haystack::PermissionErr] if missing read
  ** permission in current context.  Or if checked is false return null for
  ** those items.
  Dict?[] readByIdsList(Ref[] ids, Bool checked := true)
  {
    readerByIds(ids, false).dicts(checked)
  }

  ** Read a list of records by ids into a grid.  The rows in the result
  ** correspond by index to the ids list.  If checked is true, throw
  ** [haystack::UnknownRecErr] if any id is not found, or throw [haystack::PermissionErr]
  ** if missing read permission in current context.  Or if checked is false
  ** return a row with every column set to null (including the `id` tag)
  ** in those cases.
  Grid readByIds(Ref[] ids, Bool checked := true)
  {
    readerByIds(ids, false).grid(null, checked)
  }

  ** Read a list of underlying record wrappers by id.  The resulting list matches
  ** the list of ids by index.  If checked is true, throw [haystack::UnknownRecErr]
  ** if any id is not found, or throw [haystack::PermissionErr] if missing read
  ** permission in current context.  Or if checked is false return null for
  ** those items.
  @NoDoc FolioRec?[] readRecsById(Ref[] ids, Bool checked := true)
  {
    readerByIds(ids, false).recs(checked)
  }

  ** Read record by id whether rec is in trash or not.  If checked is true,
  ** throw [haystack::UnknownRecErr] if not found, or throw [haystack::PermissionErr]
  ** if missing read permission in current context.  Or if checked is false
  ** return null in those cases.
  @NoDoc Dict? readByIdTrash(Ref id, Bool checked := true)
  {
    readerByIds([id], true).dict(checked)
  }

  ** Read raw recs by id with all security checks and error priority applied
  private FolioIdsReader readerByIds(Ref[] ids, Bool includeTrash)
  {
    FolioIdsReader(ids, checkRead.doReadRecsById(ids), includeTrash)
  }

  ** Return the number of records which match given [filter](ph.doc::Filters).
  ** This method supports the same options and security semantics as [readAll].
  Int readCount(Filter filter, Dict? opts := null)
  {
    checkRead
    reader := FolioCountReader(filter, opts)
    if (reader.limit <= 0) return 0

    // check if we can delegate to subtype for optimized count
    if (reader.canFastCount) return doReadCount(filter)

    doReadAllEachWhile(filter, reader)
    return reader.count
  }

  ** Find the first record which matches the given [filter](ph.doc::Filters).
  ** If checked is true, throw [haystack::UnknownRecErr] if none found.  Or if
  ** checked is false return null.  Recs missing read permission in current context
  ** are silently excluded from the match; a [haystack::PermissionErr] is never
  ** thrown.
  Dict? read(Filter filter, Bool checked := true)
  {
    scan(filter, optsLimit1, false).dict(checked)
  }

  ** Options constant for {limit:1}
  private const static Dict optsLimit1 := Etc.dict1("limit", Number(1))

  ** Match all the records against a [filter](ph.doc::Filters) and return
  ** as list.  This method uses same options and security semantics
  ** as [readAll].
  Dict[] readAllList(Filter filter, Dict? opts := null)
  {
    scan(filter, opts, false).dicts
  }

  ** Match all the records against a [filter](ph.doc::Filters) and
  ** return as grid.  Recs missing read permission in current context
  ** are silently excluded; a [haystack::PermissionErr] is never thrown.
  **
  ** Options:
  **   - limit: max number of recs to read
  **   - search: search string to apply in addition to filter
  **   - sort: marker tag to sort recs by dis string
  **   - gridMeta: Dict to use for grid meta
  Grid readAll(Filter filter, Dict? opts := null)
  {
    scan(filter, opts, false).grid(opts, false)
  }

  ** Match all the records in the trash against a [filter](ph.doc::Filters)
  ** and return as grid.  Only records with the `trash` tag are returned;
  ** every other read method excludes them.  Uses the same options and
  ** security semantics as [readAll].
  @NoDoc Grid readTrash(Filter filter, Dict? opts := null)
  {
    scan(filter, opts, true).grid(opts, false)
  }

  ** Read all records matching filter.  Recs missing read permission
  ** in current context are silently excluded.
  @NoDoc Obj? readAllEach(Filter filter, Dict? opts, |Dict| f)
  {
    readAllEachWhile(filter, opts) |x| { f(x); return null }
  }

  ** Read all records matching filter until callback returns non-null.
  ** Recs missing read permission in current context are silently excluded.
  @NoDoc Obj? readAllEachWhile(Filter filter, Dict? opts, |Dict->Obj?| f)
  {
    checkRead
    reader := FolioEachReader(filter, opts, f)
    if (reader.limit <= 0) return null
    doReadAllEachWhile(filter, reader)
    return reader.result
  }

  ** Read all recs matching filter with all options and security applied.
  ** The value returned by the eachWhile hooks is _not_ the result of the
  ** read - it may be the reader's internal break sentinel - so callers
  ** use the reader for results.
  private FolioAccReader scan(Filter filter, Dict? opts, Bool trash)
  {
    checkRead
    reader := FolioAccReader(filter, opts)
    if (reader.limit > 0)
    {
      if (trash) doReadTrashEachWhile(filter, reader)
      else doReadAllEachWhile(filter, reader)
    }
    return reader
  }

  ** Read only persistent tags for given rec id.  If checked is true,
  ** throw [UnknownRecErr] if not found, or throw [PermissionErr] if missing
  ** read permission in current context.  Or if checked is false return null
  ** in those cases.
  @NoDoc Dict? readByIdPersistentTags(Ref id, Bool checked := true)
  {
    readRecById(id, checked)?.persistent
  }

  ** Read only transient tags for given rec id.  If checked is true,
  ** throw [UnknownRecErr] if not found, or throw [PermissionErr] if missing
  ** read permission in current context.  Or if checked is false return null
  ** in those cases.
  @NoDoc Dict? readByIdTransientTags(Ref id, Bool checked := true)
  {
    readRecById(id, checked)?.transient
  }

  ** Intern the given ref to its canonical representation
  @NoDoc virtual Ref internRef(Ref id)
  {
    rec := readById(id, false)
    if (rec != null) return rec.id
    return id
  }

//////////////////////////////////////////////////////////////////////////
// Read Implementations
//////////////////////////////////////////////////////////////////////////

  ** Read a live or trashed rec by id.
  ** Must resolve relative refs against `idPrefix`.
  ** - Never check permissions
  @NoDoc protected abstract FolioRec? doReadRecById(Ref id)

  ** Read a list of live or trashed recs by id.
  ** The default implementation maps [doReadRecById].
  ** Must resolve relative refs against `idPrefix`.
  ** - Never check permissions
  @NoDoc protected virtual FolioRec?[] doReadRecsById(Ref[] ids)
  {
    ids.map |id->FolioRec?| { doReadRecById(id) }
  }

  ** Subclass implementation to stream every rec matching filter
  ** to the reader until [FolioReader.accept] returns non-null, in which
  ** case return that value.
  ** - Never read recs in the trash
  ** - Never check permissions
  @NoDoc protected abstract Obj? doReadAllEachWhile(Filter filter, FolioReader reader)

  ** Subclass implementation to stream every rec in the trash matching filter
  ** - Never check permissions
  @NoDoc protected abstract Obj? doReadTrashEachWhile(Filter filter, FolioReader reader)

  ** Subclass hook to count matching the filter. The base class only calls this
  ** when no context is installed and no options need to be applied, so subclasses
  ** are free to optimize.
  ** - Never count recs in the trash
  ** - Never check permissions
  @NoDoc protected virtual Int doReadCount(Filter filter)
  {
    reader := FolioCountReader(filter, null)
    doReadAllEachWhile(filter, reader)
    return reader.count
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
    recs := scan(Filter.has("trash"), null, true).dicts
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
    oldRecs := doReadRecsById(diffs.map |diff->Ref| { diff.id })
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

