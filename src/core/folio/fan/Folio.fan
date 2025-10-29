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
    rec := checkRead.doReadRecById(id)
    if (rec != null)
    {
      cx := FolioContext.curFolio(false)
      if (cx == null || cx.canRead(rec.dict)) return rec
      if (checked) throw UnknownRecErr("Cannot read: $id.toZinc")
    }
    if (checked) throw UnknownRecErr(id.toZinc)
    return null
  }

  ** Read underlying record (return null for trash, do _not_ check permissions)
  @NoDoc protected abstract FolioRec? doReadRecById(Ref id)

  ** Convenience for `readByIds` with single id.
  Dict? readById(Ref id, Bool checked := true)
  {
    readRecById(id, checked)?.dict
  }

  ** Read a list of records by ids into a grid.  The rows in the
  ** result correspond by index to the ids list.  If checked is true,
  ** then every id must be found in the project or UnknownRecErr
  ** is thrown.  If checked is false, then an unknown record is
  ** returned as a row with every column set to null (including
  ** the 'id' tag).
  Grid readByIds(Ref[] ids, Bool checked := true)
  {
    checkRead.doReadByIds(ids).grid(checked)
  }

  ** Read a list of records by id.  The resulting list matches
  ** the list of ids by index (null if record not found).
  Dict?[] readByIdsList(Ref[] ids, Bool checked := true)
  {
    checkRead.doReadByIds(ids).dicts(checked)
  }

  ** Return the number of records which match given [filter]`docHaystack::Filters`.
  ** This method supports the same options as `readAll`.
  Int readCount(Filter filter, Dict? opts := null)
  {
    checkRead.doReadCount(filter, opts)
  }

  ** Find the first record which matches the given [filter]`docHaystack::Filters`.
  ** Throw UnknownRecErr or return null based on checked flag.
  Dict? read(Filter filter, Bool checked := true)
  {
    checkRead.doReadAll(filter, optsLimit1).dict(checked)
  }

  ** Match all the records against a [filter]`docHaystack::Filters` and
  ** return as grid.
  **
  ** Options:
  **   - limit: max number of recs to read
  **   - search: search string to apply in addition to filter
  **   - sort: marker tag to sort recs by dis string
  **   - trash: marker tag to include recs with trash tag
  **   - gridMeta: Dict to use for grid meta
  Grid readAll(Filter filter, Dict? opts := null)
  {
    Etc.makeDictsGrid(opts?.get("gridMeta"),
      checkRead.doReadAll(filter, opts).dicts(false))
  }

  ** Match all the records against a [filter]`docHaystack::Filters` and return
  ** as list.  This method uses same semantics and options as `readAll`.
  Dict[] readAllList(Filter filter, Dict? opts := null)
  {
    checkRead.doReadAll(filter, opts).dicts
  }

  ** Read by id whether rec is in trash or not
  @NoDoc Dict? readByIdTrash(Ref? id, Bool checked := true)
  {
    // optimize for common path
    rec := readById(id, false)
    if (rec != null) return rec

    // route to readAll with trash options
    return doReadAll(Filter.eq("id", id), optsLimit1AndTrash).dict(checked)
  }

  ** Read all records matching filter.
  @NoDoc Obj? readAllEach(Filter filter, Dict? opts, |Dict| f)
  {
    checkRead.doReadAllEachWhile(filter, opts) |x| { f(x); return null }
  }

  ** Read all records matching filter until callback returns non-null.
  @NoDoc Obj? readAllEachWhile(Filter filter, Dict? opts, |Dict->Obj?| f)
  {
    checkRead.doReadAllEachWhile(filter, opts, f)
  }

  ** Subclass implementation of readByIds (must check trash & permissions); return as sync future
  @NoDoc protected abstract FolioFuture doReadByIds(Ref[] ids)

  ** Subclass implementation of readAll; return as sync future
  @NoDoc protected abstract FolioFuture doReadAll(Filter filter, Dict? opts)

  ** Subclass implementation of readCount
  @NoDoc protected abstract Int doReadCount(Filter filter, Dict? opts)

  ** Subclass implementation of readAllEachWhile
  @NoDoc protected abstract Obj? doReadAllEachWhile(Filter filter, Dict? opts, |Dict->Obj?| f)

  ** Options constant for {limit:1}
  private const static Dict optsLimit1 := Etc.dict1("limit", Number(1))

  ** Options constant for {limit:1, trash}
  private const static Dict optsLimit1AndTrash := Etc.dict2("limit", Number(1), "trash", Marker.val)

  ** Read only persistent tags for given rec id
  @NoDoc virtual Dict? readByIdPersistentTags(Ref id, Bool checked := true) { throw UnsupportedErr() }

  ** Read only transient only tags for given rec id
  @NoDoc virtual Dict? readByIdTransientTags(Ref id, Bool checked := true) { throw UnsupportedErr() }

  ** Intern the given ref to its canonical representation
  @NoDoc virtual Ref internRef(Ref id)
  {
    rec := readById(id, false)
    if (rec != null) return rec.id
    return id
  }

//////////////////////////////////////////////////////////////////////////
// Commits
//////////////////////////////////////////////////////////////////////////

  ** Convenience for `commitAll` with a single diff.
  Diff commit(Diff diff)
  {
    checkWrite.doCommitAllSync([diff], cxCommitInfo).diff
  }

  ** Apply a list of diffs to the database in batch.  Either all the
  ** changes are successfully applied, or else none of them are applied
  ** and an exception is raised.  Return updated Diffs which encapsulate
  ** both the old and new version of each record.
  **
  ** If any of the records have been modified since they were read
  ** for the given change set then ConcurrentChangeErr is thrown
  ** unless 'Diff.force' configured.
  Diff[] commitAll(Diff[] diffs)
  {
    checkWrite.doCommitAllSync(diffs, cxCommitInfo).diffs
  }

  ** Convenience for `commitAllAsync` with a single diff.
  FolioFuture commitAsync(Diff diff)
  {
    checkWrite.doCommitAllAsync([diff], cxCommitInfo)
  }

  ** Commit a list of diffs to the database asynchronously.
  FolioFuture commitAllAsync(Diff[] diffs)
  {
    checkWrite.doCommitAllAsync(diffs, cxCommitInfo)
  }

  ** Remove all records with the trash tag
  @NoDoc FolioFuture commitRemoveTrashAsync()
  {
    recs := readAllList(Filter.has("trash"), Etc.dict1("trash", Marker.val))
    diffs := recs.map |rec->Diff| { Diff(rec, null, Diff.remove.or(Diff.force)) }
    return commitAllAsync(diffs)
  }

  ** Subclass implementation of commitAll (default routes to doCommitAllAsync)
  @NoDoc virtual protected FolioFuture doCommitAllSync(Diff[] diffs, Obj? cxInfo)
  {
    doCommitAllAsync(diffs, cxInfo)
  }

  ** Subclass implementation of commitAllAsync
  @NoDoc abstract protected FolioFuture doCommitAllAsync(Diff[] diffs, Obj? cxInfo)

  ** Context commit info to pass back to FolioHooks
  private Obj? cxCommitInfo() { FolioContext.curFolio(false)?.commitInfo }

}

