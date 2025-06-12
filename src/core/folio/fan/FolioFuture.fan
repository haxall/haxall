//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Nov 2015  Brian Frank  Creation
//

using concurrent
using haystack

**
** Response from a `Folio` database that provides access to eventual result
**
abstract const class FolioFuture : Future
{
  ** Make synchronous response
  @NoDoc static new makeSync(FolioRes res) { SyncFolioFuture(res) }

  ** Make asynchronous response
  @NoDoc static new makeAsync(Future future) { AsyncFolioFuture(future) }

  ** FolioFuture is not completable
  @NoDoc override final This complete(Obj? val) { throw UnsupportedErr() }

  ** FolioFuture is not completable
  @NoDoc override final This completeErr(Err err) { throw UnsupportedErr() }

  ** Block until result ready
  @NoDoc override final Obj? get(Duration? timeout := null)
  {
    waitFor(timeout).getRes.val
  }

  ** Get the result as one Dict.  If there is no results then
  ** raise UnknownRecErr or return null based on checked flag.  If
  ** there are more than one result then return just one.
  @NoDoc Dict? dict(Bool checked := true)
  {
    rd := getRes
    dict := rd.dicts.getSafe(0)
    if (dict != null) return dict
    if (checked) throw UnknownRecErr(rd.errMsg)
    return null
  }

  ** Get the result as a list of Dicts.  If any of the resulting Dicts
  ** is null then raise UnknownRecErr if the checked flag is true.
  @NoDoc virtual Dict?[] dicts(Bool checked := true)
  {
    rd := getRes
    if (!checked) return rd.dicts
    if (rd.errs) throw UnknownRecErr(rd.errMsg)
    return rd.dicts
  }

  ** Return the result of `dicts` as a grid.  If checked is false,
  ** then an unknown records are returned as a row with every column
  ** set to null (including the 'id' tag).
  @NoDoc Grid grid(Bool checked := true)
  {
    Etc.makeDictsGrid(null, dicts(checked))
  }

  ** Return the number of items in result.
  @NoDoc Int count()
  {
    getRes.count
  }

  ** Get the resulting diff of a commit request.
  @NoDoc Diff diff()
  {
    getRes.diffs.first ?: throw Err("No diffs")
  }

  ** Get the resulting list of diffs of a commit request.
  @NoDoc Diff[] diffs()
  {
    getRes.diffs
  }

  ** Set the timeout to use before accessing the result.
  @NoDoc abstract This timeout(Duration? timeout)

  ** Get FolioRes with current timeout
  internal abstract FolioRes getRes()
}

**************************************************************************
** SyncFolioFuture
**************************************************************************

internal const class SyncFolioFuture : FolioFuture
{
  new make(FolioRes res) { this.getRes = res }
  override FutureStatus status() { FutureStatus.ok }
  override This timeout(Duration? timeout) { this }
  override This waitFor(Duration? timeout := null) { this }
  override Void cancel() {}
  override const FolioRes getRes
}

**************************************************************************
** AsyncFolioFuture
**************************************************************************

internal const class AsyncFolioFuture : FolioFuture
{
  new make(Future future) { this.future = future }
  const Future future
  const AtomicRef timeoutRef := AtomicRef(30sec)
  override Future? wraps() { future }
  override FutureStatus status() { future.status }
  override This timeout(Duration? t) { timeoutRef.val = t; return this }
  override Void cancel() { future.cancel }
  override This waitFor(Duration? timeout := null) { future.waitFor(timeout); return this }
  override FolioRes getRes() { future.get(timeoutRef.val) }
}

**************************************************************************
** FolioRes
**************************************************************************

@NoDoc
abstract const class FolioRes
{
  abstract Obj? val()
  virtual Bool errs() { false }
  virtual Str errMsg() { "" }
  abstract Int count()
  virtual Dict?[] dicts() { throw UnsupportedErr("Dicts not available") }
  virtual Diff[] diffs() { throw UnsupportedErr("Diffs not available") }
}

@NoDoc
const final class ReadFolioRes : FolioRes
{
  new make(Obj errMsgObj, Bool errs, Dict?[] dicts)
  {
    this.errMsgObj = errMsgObj
    this.errs = errs
    this.dicts = dicts
  }

  override Obj? val()  { dicts }
  override Str errMsg() { errMsgObj.toStr }
  const Obj errMsgObj
  const override Bool errs
  const override Dict?[] dicts
  override Int count() { dicts.size }
}

@NoDoc
const final class CountFolioRes : FolioRes
{
  new make(Int count) { this.count = count }
  override Obj? val()  { Number(count) }
  override const Int count
}

@NoDoc
const final class CommitFolioRes : FolioRes
{
  new make(Diff[] diffs) { this.diffs = diffs }
  override Obj? val()  { diffs }
  override Int count() { diffs.size }
  override Dict?[] dicts() { diffs.map |d->Dict?| { d.newRec } }
  override const Diff[] diffs
}

@NoDoc
const final class HisWriteFolioRes : FolioRes
{
  static const HisWriteFolioRes empty := make(Etc.dict1("count", Number.zero))
  new make(Dict dict) { this.dict = dict }
  override Obj? val()  { dict }
  override Int count() { (dict["count"] as Number ?: Number.zero).toInt }
  override Dict?[] dicts() { [dict] }
  const Dict dict
}

@NoDoc
const final class BackupFolioRes : FolioRes
{
  new make() { this.val = Etc.dict1("dis", "Backup complete") }
  override const Obj? val
  override Int count() { 1 }
}

