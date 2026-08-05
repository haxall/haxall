//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Nov 2015  Brian Frank  Creation
//

using concurrent
using xeto
using haystack

**
** Response from a [Folio] database that provides access to eventual result
**
const class FolioFuture : Future
{
  ** Make asynchronous response
  @NoDoc static FolioFuture makeAsync(Future wrap) { make(wrap) }

  ** Make completed response for an operation which is normally
  ** asynchronous, but short circuited to a known synchronous result
  @NoDoc static new makeSync(FolioRes res) { make(Future.makeCompletable.complete(res)) }

  ** Constructor always wraps future
  @NoDoc new make(Future wrap) : super.make(wrap) {}

  ** Wrap future
  @NoDoc override This wrap(Future w) { make(w) }

  ** Default timeout to use
  Duration timeout
  {
    get { timeoutRef.val }
    set { timeoutRef.val = it }
  }
  private const AtomicRef timeoutRef := AtomicRef(30sec)

  ** Get response value; timeout defaults to `timeout` field, pass null to block forever
  @NoDoc override final Obj? get(Duration? timeout := this.timeout)
  {
    getRes(timeout).val
  }

  ** Get FolioRes; timeout defaults to `timeout` field, pass null to block forever
  @NoDoc FolioRes getRes(Duration? timeout := this.timeout)
  {
    wraps.get(timeout)
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

}

**************************************************************************
** FolioRes
**************************************************************************

@NoDoc
abstract const class FolioRes
{
  abstract Obj? val()
  abstract Int count()
  virtual Dict?[] dicts() { throw UnsupportedErr("Dicts not available") }
  virtual Diff[] diffs() { throw UnsupportedErr("Diffs not available") }
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

