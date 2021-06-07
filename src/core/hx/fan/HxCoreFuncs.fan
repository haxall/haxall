//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Jun 2021  Brian Frank  Creation
//

using haystack
using axon
using folio

**
** Haxall core "hx" axon functions supported by all runtimes
**
const class HxCoreFuncs : HxLibFuncs
{
  ** Constructor
  new make(HxCoreLib lib) : super(lib) {}

//////////////////////////////////////////////////////////////////////////
// Folio Reads
//////////////////////////////////////////////////////////////////////////

  ** Read from database the first record which matches filter.
  ** If no matches found throw UnknownRecErr or null based
  ** on checked flag.  See `readAll` for how filter works.
  @Axon
  virtual Dict? read(Expr filterExpr, Expr checked := Literal.trueVal)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    check := checked.eval(cx)
    return cx.db.read(filter.toStr, check)
  }

  ** Read a record from database by 'id'.  If not found
  ** throw UnknownRecErr or return null based on checked flag.
  @Axon
  virtual Dict? readById(Ref? id, Bool checked := true)
  {
    curContext.db.readById(id, checked)
  }

  ** Given record id, read only the persistent tags from Folio.
  ** Also see `readByIdTransientTags`.
  @Axon
  virtual Dict? readByIdPersistentTags(Ref id, Bool checked := true)
  {
    curContext.db.readByIdPersistentTags(id, checked)
  }

  ** Given record id, read only the transient tags from Folio.
  ** Also see `readByIdPersistentTags`.
  @Axon
  virtual Dict? readByIdTransientTags(Ref id, Bool checked := true)
  {
    curContext.db.readByIdTransientTags(id, checked)
  }

  ** Read a record Dict by its id for hyperlinking in a UI.  Unlike other
  ** reads which return a Dict, this read returns the columns ordered in
  ** the same order as reads which return a Grid.
  @Axon
  virtual Dict? readLink(Ref? id)
  {
    cx := curContext
    rec := cx.db.readById(id ?: Ref.nullRef, false)
    if (rec == null) return rec
    gb := GridBuilder()
    row := Obj?[,]
    Etc.dictsNames([rec]).each |n| { gb.addCol(n); row.add(rec[n]) }
    gb.addRow(row)
    return gb.toGrid.first
  }

  ** Read a list of record ids into a grid.  The rows in the
  ** result correspond by index to the ids list.  If checked is true,
  ** then every id must be found in the project or UnknownRecErr
  ** is thrown.  If checked is false, then an unknown record is
  ** returned as a row with every column set to null (including
  ** the 'id' tag).
  @Axon
  virtual Grid readByIds(Ref[] ids, Bool checked := true)
  {
    curContext.db.readByIds(ids, checked)
  }

  ** Reall all records from the database which match the filter.
  ** The filter must an expression which matches the filter structure.
  ** String values may parsed into a filter using `parseFilter` function.
  @Axon
  virtual Grid readAll(Expr filterExpr, Expr? opts := null)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    if (opts != null)
    {
      optsDict := (Dict?)opts.eval(cx)
      if (optsDict != null && !optsDict.isEmpty)
      {
        grid := cx.db.readAll(filter.toStr, optsDict)
        if (optsDict.has("sort")) grid = grid.sortDis
        return grid
      }
    }
    return cx.db.readAll(filter.toStr)
  }

  ** Read a list of ids as a stream of Dict records.
  ** If checked if false, then records not found are skipped.
  ** See `docSkySpark::Streams#readByIdsStream`.
  @Axon
  virtual Obj readByIdsStream(Ref[] ids, Bool checked := true)
  {
    ReadByIdsStream(ids, checked)
  }

  ** Reall all records which match filter as stream of Dict records.
  ** See `docSkySpark::Streams#readAllStream`.
  @Axon
  virtual Obj readAllStream(Expr filterExpr)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    return ReadAllStream(filter)
  }

  ** Return the intersection of all tag names used by all the records
  ** matching the given filter.  The results are returned as a grid
  ** with following columns:
  **   - 'name': string name of the tag
  **   - 'kind': all the different value kinds separated by "|"
  **   - 'count': total number of recs with the tag
  ** Also see `readAllTagVals` and `gridColKinds`.
  @Axon
  virtual Grid readAllTagNames(Expr filterExpr)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    return HxUtil.readAllTagNames(cx.db, filter)
  }

  ** Return the range of all the values mapped to a given
  ** tag name used by all the records matching the given filter.
  ** This method is capped to 200 results.  The results are
  ** returned as a grid with a single 'val' column.
  ** Also see `readAllTagNames`.
  @Axon
  virtual Grid readAllTagVals(Expr filterExpr, Expr tagName)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    tag := tagName.eval(cx)
    vals := HxUtil.readAllTagVals(cx.db, filter, tag)
    return Etc.makeListGrid(null, "val", null, vals)
  }

  ** Return the number of records which match the given filter expression.
  @Axon
  virtual Number readCount(Expr filterExpr)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    return Number(cx.db.readCount(filter.toStr))
  }

  /* TODO: move this code to axon pod
  ** Convert a filter expression to a function which may
  ** be used with `findAll` or `find`.  The returned function
  ** accepts one parameter of Dicts and returns true/false if
  ** the Dict is matched by the filter.  Also see `parseFilter`.
  **
  ** Examples:
  **   // filter for dicts with 'equip' tag
  **   list.findAll(filterToFunc(equip))
  **
  **   // filter rows with an 'area' tag over 10,000
  **   grid.findAll(filterToFunc(area > 10_000))
  @Axon
  static Fn filterToFunc(Expr filterExpr)
  {
    cx := Context.cur
    filter := filterExpr.evalToFilter(cx)
    return FilterFn(filter)
  }
  */

  ** Coerce a value to a Ref identifier:
  **   - Ref returns itself
  **   - Row or Dict, return 'id' tag
  **   - Grid return first row id
  @Axon
  virtual Ref toRecId(Obj? val) { HxUtil.toId(val) }

  ** Coerce a value to a list of Ref identifiers:
  **   - Ref returns itself as list of one
  **   - Ref[] returns itself
  **   - Dict return 'id' tag
  **   - Dict[] return 'id' tags
  **   - Grid return 'id' column
  @Axon
  virtual Ref[] toRecIdList(Obj? val) { HxUtil.toIds(val) }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Get the current context as a Dict with the following tags:
  **   - 'username' for current user
  **   - 'userRef' id for current user
  **   - 'locale' current locale
  @Axon
  Dict context() { curContext.toDict }

  ** Get current context
  private static HxContext curContext() { HxContext.curHx }
}

**************************************************************************
** ReadAllStream
**************************************************************************

internal class ReadAllStream : SourceStream
{
  new make(Filter filter) { this.filter = filter }

  override Str funcName() { "readAllStream" }

  override Obj?[] funcArgs() { [filter] }

  override Void onStart(Signal sig)
  {
    cx := (HxContext)this.cx
    cx.db.readAllEachWhile(filter, Etc.emptyDict) |rec->Obj?|
    {
      submit(rec)
      return isComplete ? "break" : null
    }
  }

  const Filter filter
}

**************************************************************************
** ReadByIdsStream
**************************************************************************

internal class ReadByIdsStream : SourceStream
{
  new make(Ref[] ids, Bool checked) { this.ids = ids; this.checked = checked }

  override Str funcName() { "readByIdsStream" }

  override Obj?[] funcArgs() { [ids] }

  override Void onStart(Signal sig)
  {
    cx := (HxContext)this.cx
    ids.eachWhile |id|
    {
      rec := cx.db.readById(id, checked)
      if (rec == null) return null
      submit(rec)
      return isComplete ? "break" : null
    }
  }

  const Ref[] ids
  const Bool checked
}

**************************************************************************
** CommitStream
**************************************************************************

internal class CommitStream : TerminalStream
{
  new make(MStream prev) : super(prev) {}

  override Str funcName() { "commit" }

  override Void onData(Obj? data)
  {
    if (data == null) return

    // back pressure
    cx := (HxContext)this.cx
    count++
    if (count % 100 == 0) cx.db.sync

    // async commit
    diff := data as Diff ?: throw Err("Expecting Diff, not $data.typeof")
    cx.db.commitAsync(diff)
  }

  override Obj? onRun()
  {
    // block until folio queues processed
    cx := (HxContext)this.cx
    cx.db.sync

    return Number(count)
  }

  private Int count
}

