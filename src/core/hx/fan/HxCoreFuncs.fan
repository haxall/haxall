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
const class HxCoreFuncs
{

//////////////////////////////////////////////////////////////////////////
// Folio Reads
//////////////////////////////////////////////////////////////////////////

  **
  ** Read from database the first record which matches [filter]`docHaystack::Filters`.
  ** If no matches found throw UnknownRecErr or null based on checked
  ** flag.  If there are multiple matches it is indeterminate which one is
  ** returned.  See `readAll` for how filter works.
  **
  ** Examples:
  **   read(site)                 // read any site rec
  **   read(site and dis=="HQ")   // read site rec with specific dis tag
  **   read(chiller)              // raise exception if no recs with chiller tag
  **   read(chiller, false)       // return null if no recs with chiller tag
  **
  @Axon
  static Dict? read(Expr filterExpr, Expr checked := Literal.trueVal)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    check := checked.eval(cx)
    return cx.db.read(filter, check)
  }

  **
  ** Read a record from database by 'id'.  If not found
  ** throw UnknownRecErr or return null based on checked flag.
  ** In Haxall all refs are relative, but in SkySpark refs may
  ** be prefixed with something like "p:projName:r:".  This function
  ** will accept both relative and absolute refs.
  **
  ** Examples:
  **    readById(@2b00f9dc-82690ed6)          // relative ref literal
  **    readById(@:demo:r:2b00f9dc-82690ed6)  // project absolute literal
  **    readById(id)                          // read using variable
  **    readById(equip->siteRef)              // read from ref tag
  **
  @Axon
  static Dict? readById(Ref? id, Bool checked := true)
  {
    curContext.db.readById(id ?: Ref.nullRef, checked)
  }

  ** Given record id, read only the persistent tags from Folio.
  ** Also see `readByIdTransientTags` and `readById`.
  @Axon
  static Dict? readByIdPersistentTags(Ref id, Bool checked := true)
  {
    curContext.db.readByIdPersistentTags(id, checked)
  }

  ** Given record id, read only the transient tags from Folio.
  ** Also see `readByIdPersistentTags` and `readById`.
  @Axon
  static Dict? readByIdTransientTags(Ref id, Bool checked := true)
  {
    curContext.db.readByIdTransientTags(id, checked)
  }

  ** Read a record Dict by its id for hyperlinking in a UI.  Unlike other
  ** reads which return a Dict, this read returns the columns ordered in
  ** the same order as reads which return a Grid.
  @Axon
  static Dict? readLink(Ref? id)
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

  **
  ** Read a list of record ids into a grid.  The rows in the
  ** result correspond by index to the ids list.  If checked is true,
  ** then every id must be found in the database or UnknownRecErr
  ** is thrown.  If checked is false, then an unknown record is
  ** returned as a row with every column set to null (including
  ** the 'id' tag).  Either relative or project absolute refs may
  ** be used.
  **
  ** Examples:
  **   // read two relative refs
  **   readByIds([@2af6f9ce-6ddc5075, @2af6f9ce-2d56b43a])
  **
  **   // read two project absolute refs
  **   readByIds([@p:demo:r:2af6f9ce-6ddc5075, @p:demo:r:2af6f9ce-2d56b43a])
  **
  **   // return null for a given id if it does not exist
  **   readByIds([@2af6f9ce-6ddc5075, @2af6f9ce-2d56b43a], false)
  **
  @Axon
  static Grid readByIds(Ref[] ids, Bool checked := true)
  {
    curContext.db.readByIds(ids, checked)
  }

  **
  ** Reall all records from the database which match the [filter]`docHaystack::Filters`.
  ** The filter must an expression which matches the filter structure.
  ** String values may parsed into a filter using `parseFilter` function.
  **
  ** Options:
  **   - 'limit': max number of recs to return
  **   - 'sort': sort by display name
  **
  ** Examples:
  **   readAll(site)                      // read all site recs
  **   readAll(equip and siteRef==@xyz)   // read all equip in a given site
  **   readAll(equip, {limit:10})         // read up to ten equips
  **   readAll(equip, {sort})             // read all equip sorted by dis
  **
  @Axon
  static Grid readAll(Expr filterExpr, Expr? optsExpr := null)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    opts := optsExpr == null ? Etc.emptyDict : (Dict?)optsExpr.eval(cx)
    return cx.db.readAll(filter, opts)
  }

  ** Read a list of ids as a stream of Dict records.
  ** If checked if false, then records not found are skipped.
  ** See `docHaxall::Streams#readByIdsStream`.
  @Axon
  static Obj readByIdsStream(Ref[] ids, Bool checked := true)
  {
    ReadByIdsStream(ids, checked)
  }

  ** Reall all records which match filter as stream of Dict records.
  ** See `docHaxall::Streams#readAllStream`.
  @Axon
  static Obj readAllStream(Expr filterExpr)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    return ReadAllStream(filter)
  }

  **
  ** Return the intersection of all tag names used by all the records
  ** matching the given filter.  The results are returned as a grid
  ** with following columns:
  **   - 'name': string name of the tag
  **   - 'kind': all the different value kinds separated by "|"
  **   - 'count': total number of recs with the tag
  ** Also see `readAllTagVals` and `gridColKinds`.
  **
  ** Examples:
  **   // read statistics on all tags used by equip recs
  **   readAllTagNames(equip)
  **
  @Axon
  static Grid readAllTagNames(Expr filterExpr)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    return HxUtil.readAllTagNames(cx.db, filter)
  }

  **
  ** Return the range of all the values mapped to a given
  ** tag name used by all the records matching the given filter.
  ** This method is capped to 200 results.  The results are
  ** returned as a grid with a single 'val' column.
  ** Also see `readAllTagNames`.
  **
  ** Examples:
  **   // read grid of all unique point unit tags
  **   readAllTagVals(point, "unit")
  **
  @Axon
  static Grid readAllTagVals(Expr filterExpr, Expr tagName)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    tag := tagName.eval(cx)
    vals := HxUtil.readAllTagVals(cx.db, filter, tag)
    return Etc.makeListGrid(null, "val", null, vals)
  }

  **
  ** Return the number of records which match the given filter expression.
  **
  ** Examples:
  **   readCount(point)    // return number of recs with point tag
  **
  @Axon
  static Number readCount(Expr filterExpr)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    return Number(cx.db.readCount(filter))
  }

  ** Coerce a value to a Ref identifier:
  **   - Ref returns itself
  **   - Row or Dict, return 'id' tag
  **   - Grid return first row id
  @Axon
  static Ref toRecId(Obj? val) { Etc.toId(val) }

  ** Coerce a value to a list of Ref identifiers:
  **   - Ref returns itself as list of one
  **   - Ref[] returns itself
  **   - Dict return 'id' tag
  **   - Dict[] return 'id' tags
  **   - Grid return 'id' column
  @Axon
  static Ref[] toRecIdList(Obj? val) { Etc.toIds(val) }

  ** Coerce a value to a record Dict:
  **   - Row or Dict returns itself
  **   - Grid returns first row
  **   - List returns first row (can be either Ref or Dict)
  **   - Ref will make a call to read database
  @Axon
  static Dict toRec(Obj? val) { Etc.toRec(val) }

  ** Coerce a value to a list of record Dicts:
  **   - null return empty list
  **   - Ref or Ref[] (will make a call to read database)
  **   - Row or Row[] returns itself
  **   - Dict or Dict[] returns itself
  **   - Grid is mapped to list of rows
  @Axon
  static Dict[] toRecList(Obj? val) { Etc.toRecs(val) }

//////////////////////////////////////////////////////////////////////////
// Folio Writes
//////////////////////////////////////////////////////////////////////////

  **
  ** Construct a modification "diff" used by `commit`.  The orig should
  ** be the instance which was read from the database, or it may be null
  ** only if the add flag is passed.  Any tags to add/set/remove should
  ** be included in the changes dict.
  **
  ** The following flags are supported:
  **   - 'add': indicates diff is adding new record
  **   - 'remove': indicates diff is removing record (in general you
  **     should add `trash` tag instead of removing)
  **   - 'transient': indicate that this diff should not be flushed
  **     to persistent storage (it may or may not be persisted).
  **   - 'force': indicating that changes should be applied regardless
  **     of other concurrent changes which may be been applied after
  **     the orig version was read (use with caution!)
  **
  ** Examples:
  **    // create new record
  **    diff(null, {dis:"New Rec", someMarker}, {add})
  **
  **    // create new record with explicit id like Diff.makeAdd
  **    diff(null, {id:151bd3c5-6ce3cb21, dis:"New Rec"}, {add})
  **
  **    // set/add dis tag and remove oldTag
  **    diff(orig, {dis:"New Dis", -oldTag})
  **
  **    // set/add val tag transiently
  **    diff(orig, {val:123}, {transient})
  **
  @Axon
  static Diff diff(Dict? orig, Dict? changes, Dict? flags := null)
  {
    // strip null values (occurs when grid rows are used)
    if (changes == null) changes = Etc.emptyDict
    changes = Etc.dictRemoveNulls(changes)

    // flags
    mask := 0
    if (flags != null)
    {
      // handle add specially
      if (flags.has("add"))
      {
        if (orig != null) throw ArgErr("orig must be null if using 'add' flag")
        id := changes["id"] as Ref
        if (id != null) changes = Etc.dictRemove(changes, "id")
        else id = Ref.gen
        return Diff.makeAdd(changes, id)
      }

      if (flags.has("add"))       mask = mask.or(Diff.add)
      if (flags.has("remove"))    mask = mask.or(Diff.remove)
      if (flags.has("transient")) mask = mask.or(Diff.transient)
      if (flags.has("force"))     mask = mask.or(Diff.force)
    }

    return Diff(orig, changes, mask)
  }

  **
  ** Commit one or more diffs to the folio database.
  ** The argument may be one of the following:
  **   - result of `diff()`
  **   - list of `diff()` to commit multiple diffs at once
  **   - stream of `diff()`; see `docHaxall::Streams#commit`.
  **
  ** If one diff is passed, return the new record.  If a list
  ** of diffs is passed return a list of new records.
  **
  ** This is a synchronous blocking call which will return
  ** the new record or records as the result.
  **
  ** Examples:
  **   // add new record
  **   newRec: commit(diff(null, {dis:"New Rec!"}, {add}))
  **
  **   // add someTag to some group of records
  **   readAll(filter).toRecList.map(r => diff(r, {someTag})).commit
  **
  @Axon { admin = true }
  static Obj? commit(Obj diffs)
  {
    if (diffs is MStream) return CommitStream(diffs).run

    cx := curContext
    cx.readCacheClear

    if (diffs is Diff)
    {
      return cx.db.commit(diffs).newRec
    }

    if (diffs is List && ((List)diffs).all { it is Diff })
    {
      return cx.db.commitAll(diffs).map |r| { r.newRec }
    }

    throw Err("Invalid diff arg: ${diffs.typeof}")
  }

  ** Store a password key/val pair into current project's password
  ** store.  The key is typically a Ref of the associated record.
  ** If the 'val' is null, then the password will be removed.
  ** See `docHaxall::Folio#passwords`.
  **
  ** pre>
  ** passwordSet(@abc-123, "password")
  ** passwordSet(@abc-123, null)
  ** <pre
  @Axon { admin = true }
  static Void passwordSet(Obj key, Str? val)
  {
    // extra security check just to be sure!
    cx := curContext
    if (!cx.user.isAdmin) throw PermissionErr("passwordSet")

    if (val == null) cx.db.passwords.remove(key.toStr)
    else cx.db.passwords.set(key.toStr, val)
  }

  ** Strip any tags which cannot be persistently committed to Folio.
  ** This includes special tags such as 'hisSize' and any transient tags
  ** the record has defined.  If 'val' is Dict, then a single Dict is returned.
  ** Otherwise 'val' must be Dict[] or Grid and Dict[] is returned.
  ** The 'mod' tag is stripped unless the '{mod}' option is specified.
  ** The 'id' tag is not stripped for cases when adding records with
  ** swizzled ids; pass '{-id}' in options to strip the 'id' tag also.
  **
  ** Examples:
  **   // strip uncommittable tags and keep id
  **   toCommit: rec.stripUncommittable
  **
  **   // strip uncommittable tags and the id tag
  **   toCommit: rec.stripUncommittable({-id})
  **
  **   // strip uncommittable tags, but keep id and mod
  **   toCommit: rec.stripUncommittable({mod})
  @Axon
  static Obj stripUncommittable(Obj val, Obj? opts := null)
  {
    opts = Etc.makeDict(opts)
    if (val is Dict) return FolioUtil.stripUncommittable(curContext.db, val, opts)
    if (val is Grid) return ((Grid)val).mapToList |r->Dict| { stripUncommittable(r, opts) }
    if (val is List) return ((List)val).map |r->Dict| { stripUncommittable(r, opts) }
    throw ArgErr("Must be Dict, Dict[], or Grid: $val.typeof")
  }

//////////////////////////////////////////////////////////////////////////
// Runtime
//////////////////////////////////////////////////////////////////////////

  ** Return `hx::HxRuntime.isSteadyState`
  @Axon
  static Bool isSteadyState()
  {
    curContext.rt.isSteadyState
  }

  ** Enable a library by name in the runtime:
  **   libAdd("mqtt")
  @Axon { admin = true }
  static Dict libAdd(Str name, Dict? tags := null)
  {
    curContext.rt.libs.add(name, tags ?: Etc.emptyDict).rec
  }

  ** Disable a library by name in the runtime:
  **   libRemove("mqtt")
  @Axon { admin = true }
  static Obj? libRemove(Obj name)
  {
    curContext.rt.libs.remove(name)
    return "removed"
  }

  ** Return grid of enabled libs and their current status.  Columns:
  **  - name: library name string
  **  - libStatus: status enumeration string
  **  - statusMsg: additional message string or null
  @Axon { admin = true }
  static Grid libStatus()
  {
    curContext.rt.libs.status
  }

  ** Grid of installed services.  Format of the grid is subject to change.
  @Axon { admin = true }
  static Grid services()
  {
    services := curContext.rt.services
    gb := GridBuilder()
    gb.addCol("type").addCol("qname")
    services.list.each |type|
    {
      services.getAll(type).each |service|
      {
        gb.addRow2(type.qname, service.typeof.qname)
      }
    }
    return gb.toGrid
  }

//////////////////////////////////////////////////////////////////////////
// Using Spec Libs
//////////////////////////////////////////////////////////////////////////

  ** Get the list of installed Xeto libs and their current enable status.
  @NoDoc @Axon
  static Grid usingStatus()
  {
    gb := GridBuilder()
    gb.addCol("qname")
      .addCol("libStatus")
      .addCol("enabled")
      .addCol("loaded")
      .addCol("version")
      .addCol("doc")

   cx := curContext
   cx.usings.env.registry.list.each |lib|
   {
     libName := lib.name
     isSys := libName == "sys"
     isEnabled := cx.usings.isEnabled(libName)

     gb.addRow([
       libName,
       isEnabled ? "ok" : "disabled",
       isSys ? "boot" : Marker.fromBool(isEnabled),
       Marker.fromBool(lib.isLoaded),
       lib.version.toStr,
       lib.doc,
       ])
    }

    return gb.toGrid.sort |a, b|
    {
      if (a["enabled"] == b["enabled"]) return a->qname <=> b->qname
      return a.has("enabled") ? -1 : 1
    }
  }

  ** Enable one or more Xeto libs by qname
  @NoDoc @Axon { admin = true }
  static Obj usingAdd(Obj qname)
  {
    if (qname is List) return ((List)qname).map |n| { usingAdd(n) }
    if (qname == "sys") return "sys"
    cx := curContext
    rec := cx.db.read(Filter.eq("using", (Str)qname), false)
    if (rec == null) rec = cx.db.commit(Diff.makeAdd(["using":qname])).newRec
    return rec
  }

  ** Disable or more Xeto libs by qname
  @NoDoc @Axon { admin = true }
  static Obj usingRemove(Obj qname)
  {
    if (qname is List) return ((List)qname).map |n| { usingRemove(n) }
    cx := curContext
    rec := cx.db.read(Filter.eq("using", (Str)qname), false)
    if (rec != null) cx.db.commit(Diff(rec, null, Diff.remove))
    return "removed"
  }

//////////////////////////////////////////////////////////////////////////
// Observables
//////////////////////////////////////////////////////////////////////////

  @NoDoc @Axon { admin = true }
  static Grid observables()
  {
    cx := curContext
    gb := GridBuilder()
    gb.addCol("observable").addCol("subscriptions").addCol("doc")
    cx.rt.obs.list.each |o|
    {
      doc := cx.ns.def(o.name, false)?.get("doc") ?: ""
      gb.addRow([o.name, Number(o.subscriptions.size), doc])
    }
    return gb.toGrid
  }

  @NoDoc @Axon { admin = true }
  static Grid subscriptions()
  {
    cx := curContext
    gb := GridBuilder()
    gb.addCol("observable").addCol("observer").addCol("config")
    cx.rt.obs.list.each |o|
    {
      o.subscriptions.each |s|
      {
        gb.addRow([o.name, s.observer.toStr, s.configDebug])
      }
    }
    return gb.toGrid
  }

//////////////////////////////////////////////////////////////////////////
// Watches
//////////////////////////////////////////////////////////////////////////

  ** Return if given record is under at least one watch.
  ** The rec argument can be any value accepted by `toRecId()`.
  @Axon static Bool isWatched(Obj rec)
  {
    curContext.rt.watch.isWatched(Etc.toId(rec))
  }

  ** Open a new watch on a grid of records.  The 'dis' parameter
  ** is used for the watch's debug display string.  Update and return
  ** the grid with a meta 'watchId' tag.  Also see `hx::HxWatchService.open`
  ** and `docHaxall::Watches#axon`.
  **
  ** Example:
  **   readAll(myPoints).watchOpen("MyApp|Points")
  @Axon
  static Grid watchOpen(Grid grid, Str dis)
  {
    cx := curContext
    watch := cx.rt.watch.open(dis)
    watch.addGrid(grid)
    return grid.addMeta(["watchId":watch.id])
  }

  ** Poll an open watch and return all the records which have changed
  ** since the last poll.  Raise exception if watchId doesn't exist
  ** or has expired.  Also see `hx::HxWatch.poll` and `docHaxall::Watches#axon`.
  @Axon
  static Grid watchPoll(Obj watchId)
  {
    // if Haystack API, extract args
    cx := curContext
    refresh := false
    if (watchId is Grid)
    {
      grid := (Grid)watchId
      watchId = grid.meta["watchId"] as Str ?: throw Err("Missing meta.watchId")
      refresh = grid.meta.has("refresh")
    }

    // poll refresh or cov
    watch := cx.rt.watch.get(watchId)
    recs := refresh ? watch.poll(Duration.defVal) : watch.poll
    return Etc.makeDictsGrid(["watchId":watchId], recs)
  }

  ** Add a grid of recs to an existing watch and return the grid passed in.
  @Axon
  static Grid watchAdd(Str watchId, Grid grid)
  {
    cx := curContext
    watch := cx.rt.watch.get(watchId)
    watch.addGrid(grid)
    return grid
  }

  ** Remove a grid of recs from an existing watch and return grid passed in.
  @Axon
  static Grid watchRemove(Str watchId, Grid grid)
  {
    cx := curContext
    watch := cx.rt.watch.get(watchId)
    watch.removeGrid(grid)
    return grid
  }

  ** Close an open watch by id.  If the watch does not exist or
  ** has expired then this is a no op.  Also see `hx::HxWatch.close`
  ** and `docHaxall::Watches#axon`.
  @Axon
  static Obj? watchClose(Str watchId)
  {
    curContext.rt.watch.get(watchId, false)?.close
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Misc
//////////////////////////////////////////////////////////////////////////

  ** Return [about]`op:about` dict
  @Axon
  static Dict about() { curContext.about }

  ** Get the current context as a Dict with the following tags:
  **   - 'username' for current user
  **   - 'userRef' id for current user
  **   - 'locale' current locale
  **
  ** SkySpark tags:
  **   - 'projName' if evaluating in context of a project
  **   - 'nodeId' local cluster node id
  **   - 'ruleRef' if evaluating in context of a rule engine
  **   - 'ruleTuning' if evaluating in context of rule engine
  @Axon
  static Dict context() { curContext.toDict }

  ** Return list of installed Fantom pods
  @Axon { admin = true }
  static Grid pods() { HxUtil.pods }

  ** Return the installed timezone database as Grid with following columns:
  **   - name: name of the timezone
  **   - fullName: qualified name used by Olson database
  @Axon
  static Grid tzdb() { HxUtil.tzdb }

  ** Return the installed unit database as Grid with following columns:
  **   - quantity: dimension of the unit
  **   - name: full name of the unit
  **   - symbol: the abbreviated Unicode name of the unit
  @Axon
  static Grid unitdb() { HxUtil.unitdb }

  //@Axon Str diagnostics() { ((Int)Env.cur.diagnostics["mem.heap"]).toLocale("B") }

  ** Debug dump of all threads
  @NoDoc @Axon { su = true }
  static Str threadDump() { HxUtil.threadDumpAll }

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

