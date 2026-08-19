//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jul 2026  Brian Frank  Creation
//

using xeto
using haystack
using axon
using folio
using hx

**
** Project Haystack "ph.api" axon functions which define the
** standard Haystack network API
**
@Gen
const class PhApiFuncs
{

//////////////////////////////////////////////////////////////////////////
// Nav
//////////////////////////////////////////////////////////////////////////

  ** Navigate a project for learning and discovery.  This operation allows
  ** servers to expose the database in a human-friendly tree (or graph)
  ** that can be explored.
  **
  ** Request: a grid with a single row and a `navId` column.  If the grid
  ** is empty or navId is null, then the request is for the navigation root.
  **
  ** Response: a grid of navigation children for the navId specified by the
  ** request.  There is always a `navId` column that indicates the opaque
  ** identifier used to navigate to the next level of that row.  If the
  ** navId of a row is null, then the row is a leaf item with no children.
  **
  ** Navigation rows do not necessarily correspond to entities in the
  ** database.  However, if a navigation row has an `id` column, then it is
  ** safe to assume the row maps to an entity.  Clients must treat the
  ** navId as an opaque identifier.
  **
  ** See [ph.doc::Ops#nav].
  @Api @Axon
  static Grid nav(Grid req)
  {
    cx := curContext

    // delegate to a project defined nav function if installed; must skip
    // any func marked <op> which would resolve back to this one
    func := cx.ns.funcs.getAll("nav").find |x| { x.meta.missing("op") }
    if (func != null) return func.func.thunk.callList([req])

    // use simple site/equip/point navigation
    navId := req.first?.get("navId") as Ref
    if (navId == null)
    {
      // if querying root, try sites first
      sites := cx.db.readAllList(Filter("site"))
      if (!sites.isEmpty) return navRespond(sites)

      // if no sites, then try equip
      equips := cx.db.readAllList(Filter("equip"))
      if (!equips.isEmpty) return navRespond(equips)

      // if no equip, then return points
      return navRespond(cx.db.readAllList(Filter("point")))
    }

    // try to navigate site/equip or equip/point
    rec := cx.db.readById(navId)
    if (rec.has("site"))
      return navRespond(cx.db.readAllList(Filter("equip and siteRef==$rec.id.toCode")))
    else if (rec.has("equip"))
      return navRespond(cx.db.readAllList(Filter("point and equipRef==$rec.id.toCode")))
    else
      return Etc.emptyGrid
  }

  private static Grid navRespond(Dict[] recs)
  {
    if (recs.isEmpty) return Etc.emptyGrid
    recs = recs.map |rec->Dict|
    {
      if (rec.has("point")) return rec
      return Etc.dictSet(rec, "navId", rec.id)
    }
    Etc.sortDictsByDis(recs)
    return Etc.makeDictsGrid(null, recs)
  }

//////////////////////////////////////////////////////////////////////////
// His Read
//////////////////////////////////////////////////////////////////////////

  ** Read time-series data from one or more historized points.  Both a
  ** single point read and a batch read are supported; the mode is
  ** determined by the presence of a `range` tag in the request grid meta.
  **
  ** Single request: a grid with exactly one row and following columns:
  **   - `id`: Ref identifier of the historized point
  **   - `range`: Str encoding of a date-time range
  **
  ** Single response: rows represent timestamp/value pairs with a DateTime
  ** `ts` column and a `val` column.  Grid meta:
  **   - `id`: Ref of the point read
  **   - `hisStart`: DateTime for the inclusive range start in the point's tz
  **   - `hisEnd`: DateTime for the exclusive range end in the point's tz
  **
  ** Batch request: a grid with one or more rows, each with an `id` column.
  ** Grid meta:
  **   - `range`: Str encoding of a date-time range
  **   - `tz`: optional Str timezone name for the results
  **
  ** Batch response: rows represent timestamp/value pairs with a DateTime
  ** `ts` column followed by value columns named "v0", "v1", "v2" and so on.
  ** Each value column's meta must include the point `id` tag, and the
  ** columns must be ordered according to the request grid.  Results are
  ** joined on a shared `ts` column for each unique timestamp; if a point
  ** has no sample for a row then its cell is null.  Batch read requires
  ** that all queried points share a configured timezone unless `tz` is
  ** given in the request meta.
  **
  ** The range Str is formatted as one of:
  **   - "today"
  **   - "yesterday"
  **   - "{date}"
  **   - "{date},{date}"
  **   - "{dateTime},{dateTime}"
  **   - "{dateTime}"  // anything after the given timestamp
  **
  ** Ranges are inclusive of the start timestamp and exclusive of the end
  ** timestamp.  The date and dateTime options must be correctly Zinc
  ** encoded.  Date based ranges are inferred to run from midnight of the
  ** starting date to midnight of the day after the ending date, using the
  ** timezone of the point being queried.
  **
  ** Clients should query using the configured timezone of the point.  If a
  ** different timezone is specified in the range then servers must convert
  ** to the point's configured timezone before executing the query.  Results
  ** are always in the point's configured timezone.
  **
  ** See [ph.doc::Ops#hisread].
  @Api @Axon
  static Grid hisRead(Grid req)
  {
    cx := curContext
    if (req.isEmpty) throw Err("Request grid is empty")
    if (req.meta.has("range"))
      return hisReadBatch(req, cx)
    else
      return hisReadSingle(req, cx)
  }

  private static Grid hisReadSingle(Grid req, Context cx)
  {
    reqRow := req[0]
    rec := cx.db.readById(reqRow.id)
    tz := FolioUtil.hisTz(rec)
    span := parseRange(tz, reqRow->range).toTimeZone(tz)

    meta := [
      "id": rec.id,
      "hisStart": span.start,
      "hisEnd": span.end
    ]

    gb := GridBuilder().setMeta(meta).addCol("ts").addCol("val")
    cx.rt.exts.his.read(rec, span, req.meta) |item|
    {
      if (item.ts < span.start) return
      if (item.ts >= span.end) return
      gb.addRow2(item.ts, item.val)
    }
    return gb.toGrid
  }

  private static Grid hisReadBatch(Grid req, Context cx)
  {
    // read all the records
    recs := Dict[,]
    req.each |row| { recs.add(cx.db.readById(row.id)) }
    if (recs.isEmpty) throw Err("No recs")

    // determine tz to use
    TimeZone? tz
    tzName := req.meta["tz"] as Str
    if (tzName != null) tz = TimeZone.fromStr(tzName)
    else
    {
      // if meta.tz unspecified then all points must have same tz
      tz = FolioUtil.hisTz(recs[0])
      recs.each |rec|
      {
        if (tz !== FolioUtil.hisTz(recs[0]))
          throw Err("Points do not share same tz, pass tz in meta")
      }
    }

    // now we can get the span to use
    span := parseRange(tz, req.meta->range).toTimeZone(tz)

    // read all points into in-memory rows keyed by ts
    rows := DateTime:Obj?[][:]
    recs.each |rec, i|
    {
      hisReadBatchPoint(req, cx, rec, span) |ts, val|
      {
        row := rows[ts]
        if (row == null)
        {
          row = Obj?[,]
          row.size = recs.size + 1
          row[0] = ts
          rows[ts] = row
        }
        row[i+1] = val
      }
    }

    // build response grid
    gb := GridBuilder()
    gb.setMeta(["hisStart":span.start, "hisEnd":span.end])
    gb.addCol("ts")
    recs.each |rec, i| { gb.addCol("v" + i, ["id":rec.id]) }
    rows.keys.sort.each |ts|
    {
      gb.addRow(rows[ts])
    }
    return gb.toGrid
  }

  private static Void hisReadBatchPoint(Grid req, Context cx, Dict rec, Span span, |DateTime, Obj val| f)
  {
    cx.rt.exts.his.read(rec, span, req.meta) |item|
    {
      if (item.ts < span.start) return
      if (item.ts >= span.end) return
      f(item.ts.toTimeZone(span.tz), item.val)
    }
  }

  ** Parse the his read range string into a span
  @NoDoc static Span parseRange(TimeZone tz, Str q)
  {
    try
    {
      if (q == "today")     return DateSpan.today.toSpan(tz)
      if (q == "yesterday") return DateSpan.yesterday.toSpan(tz)

      Obj? start := null
      Obj? end := null
      comma := q.index(",")
      if (comma == null)
      {
        start = ZincReader(q.in).readVal
      }
      else
      {
        start = ZincReader(q[0..<comma].trim.in).readVal
        end   = ZincReader(q[comma+1..-1].trim.in).readVal
      }

      if (start is Date)
      {
        if (end == null) return DateSpan.make(start).toSpan(tz)
        if (end is Date) return DateSpan.make(start, end).toSpan(tz)
      }
      else if (start is DateTime)
      {
        if (end == null) return Span.makeAbs(start, DateTime.now.toTimeZone(((DateTime)start).tz))
        if (end is DateTime) return Span.makeAbs(start, end)
      }

      throw Err("Invalid range: $q")
    }
    catch (Err e) throw ParseErr("Invalid history range: $q", e)
  }

//////////////////////////////////////////////////////////////////////////
// His Write
//////////////////////////////////////////////////////////////////////////

  ** Post new time-series data to one or more historized points.  The points
  ** must already be configured on the server and assigned a unique
  ** identifier.  Both a single write and a batch write are supported; the
  ** mode is determined by the presence of an `id` tag in the request grid
  ** meta.
  **
  ** Single request: grid meta defines the `id` Ref of the point.  The rows
  ** define new timestamp/value samples with following columns:
  **   - `ts`: DateTime timestamp of the sample in the point's timezone
  **   - `val`: value of each timestamp sample
  **
  ** Batch request: omit the grid meta `id` and instead add multiple value
  ** columns where the id is specified in the column meta:
  **   - `ts`: DateTime timestamp
  **   - `v{i}`: value column for each point, column meta must define `id`
  **
  ** Response: empty grid
  **
  ** Clients should attempt to avoid writing duplicate data, but servers
  ** must gracefully handle clients posting out-of-order or duplicate
  ** history data.  The timestamp and value kind of posted data must match
  ** the entity's configured timezone and kind.  Numeric data posted must
  ** either be unitless or match the entity's configured unit; timezone,
  ** value kind, and unit conversion are explicitly disallowed.
  **
  ** See [ph.doc::Ops#hiswrite].
  @Api @Axon
  static Grid hisWrite(Grid req)
  {
    cx := curContext

    // check security
    cx.checkAdmin("hisWrite op")

    // check for single vs batch
    if (req.meta.has("id"))
      hisWriteSingle(req, cx)
    else
      hisWriteBatch(req, cx)

    return Etc.emptyGrid
  }

  private static Void hisWriteSingle(Grid req, Context cx)
  {
    hisWriteCol(req, cx, req.meta.id, req.col("ts"), req.col("val"))
  }

  private static Void hisWriteBatch(Grid req, Context cx)
  {
    tsCol := req.cols[0]
    if (tsCol.name != "ts") throw Err("First col must be named 'ts', not '$tsCol.name'")

    req.cols.eachRange(1..-1) |valCol|
    {
      id := valCol.meta["id"] as Ref ?: throw Err("Col missing id tag: $valCol.name")
      hisWriteCol(req, cx, id, tsCol, valCol)
    }
  }

  private static Void hisWriteCol(Grid req, Context cx, Ref id, Col tsCol, Col valCol)
  {
    // lookup history record
    rec := cx.db.readById(id)

    // map ts/val rows into HisItem list
    items := HisItem[,]
    items.capacity = req.size
    req.each |row|
    {
      tsRaw := row.val(tsCol)
      ts := tsRaw as DateTime ?: throw Err("Timestamp value is not DateTime: $tsRaw [${tsRaw?.typeof}]")
      val := row.val(valCol)
      if (val == null) return
      items.add(HisItem(ts, val))
    }

    // perform write
    opts := req.meta
    cx.rt.exts.his.write(rec, items, opts)
  }

//////////////////////////////////////////////////////////////////////////
// Point Write
//////////////////////////////////////////////////////////////////////////

  ** Read the current status of a writable point's priority array, or write
  ** to one of its levels.  The mode is determined by the presence of the
  ** `level` parameter.
  **
  ** Read: pass only `id` and the response is a grid with the current
  ** priority array state:
  **   - `level`: number from 1 - 17 (17 is default)
  **   - `levelDis`: human description of the level
  **   - `val`: current value at the level or null
  **   - `who`: who last controlled the value at this level
  **
  ** Write parameters:
  **   - `id`: Ref identifier of the writable point
  **   - `level`: Number from 1-17 for the level to write
  **   - `val`: value to write, or null to auto the level
  **   - `who`: optional username/application name performing the write,
  **     otherwise the authenticated user's display name is used
  **   - `duration`: Number with duration unit if setting level 8
  **
  ** Write response: empty grid
  **
  ** A version 4 request carries the parameters as the columns of a
  ** single row request grid.
  **
  ** See [ph.doc::Ops#pointwrite].
  @Api @Axon
  static Grid pointWrite(Ref id, Number? level := null, Obj? val := null, Str? who := null, Number? duration := null)
  {
    cx := curContext
    rec := cx.db.readById(id)

    // if reading level will be null
    if (level == null) return cx.rt.exts.point.pointArray(rec)

    // handle write
    cx.checkAdmin("pointWrite op")
    who = "Haystack.pointWrite | " + (who ?: cx.user.dis)

    // if have timed override
    if (val != null && level.toInt == 8 && duration != null)
      val = Etc.dict2("val", val, "duration", duration.toDuration)

    cx.rt.exts.point.pointWrite(rec, val, level.toInt, who).get(30sec)
    return Etc.makeEmptyGrid(Etc.dict1("ok", Marker.val))
  }

//////////////////////////////////////////////////////////////////////////
// Watches
//////////////////////////////////////////////////////////////////////////

  ** Create a new watch or add entities to an existing watch.
  **
  ** If the entities subscribed are themselves proxies for external data
  ** sources, then this operation should perform a downstream data refresh.
  ** It is an implementation detail whether that refresh occurs
  ** synchronously or asynchronously, so clients must expect that the
  ** latest data might not be available until a subsequent poll.
  **
  ** Request: a row for each entity to subscribe with an `id` column of
  ** Ref values.  Grid meta:
  **   - `watchDis`: debug/display string required when creating a new watch
  **   - `watchId`: Str watch identifier required to add entities to an
  **     existing watch; if omitted the server must open a new watch
  **   - `lease`: optional Number with duration unit for the desired lease
  **     period (the server is free to ignore it)
  **
  ** Response: rows correspond to the current entity state of the requested
  ** identifiers, each response row corresponding to the request grid and
  ** its respective row ordering.  If an id from the request was not found,
  ** the response includes a row of all null cells.  Grid meta:
  **   - `watchId`: required Str identifier of the watch
  **   - `lease`: required Number with duration unit for the server assigned
  **     lease period
  **
  ** Clients may subscribe using an id which is not the server's canonical
  ** id.  The canonical id is the one returned in the response, and servers
  ** must use that same id when polling.  Clients must not assume the
  ** request id equals the response id, but row ordering is guaranteed so
  ** clients can map between them.
  **
  ** If the response is an error grid then the client must assume the watch
  ** is no longer valid and open a new one.
  **
  ** See [ph.doc::Ops#watchsub].
  @Api @Axon
  static Grid watchSub(Grid req)
  {
    cx := curContext

    // lookup or create watch
    watchId := req.meta["watchId"] as Str
    watch := watchId == null ?
             cx.rt.watch.open(req.meta->watchDis) :
             cx.rt.watch.get(watchId)

    // map rows to Refs
    ids := req.ids

    // set lease if specified
    lease := req.meta["lease"] as Number
    if (lease != null) watch.lease = lease.toDuration

    // add the ids
    watch.addAll(ids)

    // return recs - must return row for each requested id (so don't use Etc)
    resMeta := Etc.dict2("watchId", watch.id, "lease", Number.makeDuration(watch.lease, null))
    recs := cx.db.readByIdsList(ids, false)
    colNames := Etc.dictsNames(recs)
    gb := GridBuilder()
    gb.setMeta(resMeta)
    if (colNames.isEmpty)
    {
      // this is what happens when we have zero matches from request
      gb.addCol("id")
      recs.each { gb.addRow1(null) }
    }
    else
    {
      // at least one rec was found
      colNames.each |colName| { gb.addCol(colName) }
      gb.addDictRows(recs)
    }
    return gb.toGrid
  }

  ** Close a watch entirely or remove entities from it.
  **
  ** Request: a row with an `id` column of Ref values for each entity to
  ** unsubscribe, if the watch is not being closed.  Grid meta:
  **   - `watchId`: Str watch identifier
  **   - `close`: Marker tag to close the entire watch
  **
  ** Response: empty grid
  **
  ** If the response is an error grid then the client must assume the watch
  ** is no longer valid and open a new one.
  **
  ** See [ph.doc::Ops#watchunsub].
  @Api @Axon
  static Grid watchUnsub(Grid req)
  {
    cx := curContext

    // parse request
    watchId := req.meta["watchId"] as Str ?: throw Err("Missing meta.watchId")
    close := req.meta.has("close")

    // lookup watch
    watch := cx.rt.watch.get(watchId, false)
    if (watch == null) return Etc.emptyGrid

    // if no rows then close, otherwise remove
    if (close)
      watch.close
    else
      watch.removeGrid(req)
    return Etc.emptyGrid
  }

  ** Poll a watch for changes to the subscribed entities.
  **
  ** Parameters:
  **   - `watchId`: required Str identifier of the watch
  **   - `refresh`: Marker to request a full refresh
  **   - `curValSub`: Marker to project the rows to just their id,
  **     curVal, and curStatus columns
  **
  ** Response: a grid where each row corresponds to a watched entity.  The
  ** `id` tag of each row identifies the changed entity and correlates to
  ** the id returned by the subscribe response.  Clients must assume no
  ** explicit ordering of the rows.
  **
  ** If the poll was for changes only then just the entities changed since
  ** the last poll are returned, and an empty grid means nothing changed.
  ** If the poll is a full refresh then a row is returned for each entity in
  ** the watch, excluding invalid identifiers.
  **
  ** If the response is an error grid then the client must assume the watch
  ** is no longer valid and open a new one.
  **
  ** A version 4 request carries the parameters as the request grid meta.
  **
  ** See [ph.doc::Ops#watchpoll].
  @Api @Axon
  static Grid watchPoll(Str watchId, Marker? refresh := null, Marker? curValSub := null)
  {
    cx := curContext

    // poll as refresh or cov
    watch := cx.rt.watch.get(watchId)
    recs := refresh != null ? watch.poll(Duration.defVal) : watch.poll
    resMeta := Etc.dict1("watchId", watchId)
    if (curValSub != null)
    {
      return GridBuilder()
        .setMeta(resMeta)
        .addCol("id")
        .addCol("curVal")
        .addCol("curStatus")
        .addDictRows(recs).toGrid
    }
    else
    {
      return Etc.makeDictsGrid(resMeta, recs)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Current context
  private static Context curContext() { Context.cur }
}

