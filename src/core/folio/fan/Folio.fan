//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Oct 2015  Brian Frank  Creation
//

using concurrent
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

  ** Block until all pending writes have processed been written to disk
  @NoDoc virtual This sync(Duration? timeout := null, Str? mgr := null) { this }

  ** Get storage for passwords and other secrets.
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
    closeAsync.timeout(timeout).getRes
  }

  ** Close the database asynchronously and return future
  FolioFuture closeAsync()
  {
    if (closedRef.getAndSet(true))
      return FolioFuture(CountFolioRes(0))
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

  ** Convenience for `readByIds` with single id.
  Dict? readById(Ref? id, Bool checked := true)
  {
    checkRead.doReadByIds([id]).dict(checked)
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
  Int readCount(Str filter, Dict? opts := null)
  {
    checkRead.doReadCount(Filter(filter), opts)
  }

  ** Find the first record which matches the given [filter]`docHaystack::Filters`.
  ** Throw UnknownRecErr or return null based on checked flag.
  Dict? read(Str filter, Bool checked := true)
  {
    checkRead.doReadAll(Filter(filter), optsLimit1).dict(checked)
  }

  ** Match all the records against a [filter]`docHaystack::Filters` and
  ** return as grid.
  **
  ** Options:
  **   - limit: max number of recs to read
  **   - trash: marker tag to include recs with trash tag
  **   - gridMeta: Dict to use for grid meta
  Grid readAll(Str filter, Dict? opts := null)
  {
    Etc.makeDictsGrid(opts?.get("gridMeta"),
      checkRead.doReadAll(Filter(filter), opts).dicts(false))
  }

  ** Match all the records against a [filter]`docHaystack::Filters` and return
  ** as list.  This method uses same semantics and options as `readAll`.
  Dict[] readAllList(Str filter, Dict? opts := null)
  {
    checkRead.doReadAll(Filter(filter), opts).dicts
  }

  ** Read with pre-parsed filter.
  @NoDoc Dict? readFilter(Filter filter, Bool checked := true)
  {
    checkRead.doReadAll(filter, optsLimit1).dict(checked)
  }

  ** Read all as list with pre-parsed filter.
  @NoDoc Dict[] readAllListFilter(Filter filter, Dict? opts := null)
  {
    checkRead.doReadAll(filter, opts).dicts
  }

  ** Read all records matching filtering until callback returns non-null.
  @NoDoc Obj? readAllEachWhile(Filter filter, Dict? opts, |Dict->Obj?| f)
  {
    checkRead.doReadAllEachWhile(filter, opts, f)
  }

  ** Subclass implementation of readByIds; return as sync future
  @NoDoc protected abstract FolioFuture doReadByIds(Ref[] ids)

  ** Subclass implementation of readAll; return as sync future
  @NoDoc protected abstract FolioFuture doReadAll(Filter filter, Dict? opts)

  ** Subclass implementation of readCount
  @NoDoc protected abstract Int doReadCount(Filter filter, Dict? opts)

  ** Subclass implementation of readAllEachWhile
  @NoDoc protected abstract Obj? doReadAllEachWhile(Filter filter, Dict? opts, |Dict->Obj?| f)

  ** Options constant for {limit:1}
  private const static Dict optsLimit1 := Etc.makeDict(["limit":Number(1)])

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
    checkWrite.doCommitAllAsync([diff], cxCommitInfo).diff
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
    checkWrite.doCommitAllAsync(diffs, cxCommitInfo).diffs
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
    recs := readAllList("trash", Etc.makeDict(["trash":Marker.val]))
    diffs := recs.map |rec->Diff| { Diff(rec, null, Diff.remove.or(Diff.force)) }
    return commitAllAsync(diffs)
  }

  ** Subclass implementation of commitAllAsync
  @NoDoc abstract protected FolioFuture doCommitAllAsync(Diff[] diffs, Obj? cxInfo)

  ** Context commit info to pass back to FolioHooks
  private Obj? cxCommitInfo() { FolioContext.curFolio(false)?.commitInfo }

}

