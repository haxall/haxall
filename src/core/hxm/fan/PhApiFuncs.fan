//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jul 2026  Brian Frank  Creation
//

using xeto
using xetom
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
// Read
//////////////////////////////////////////////////////////////////////////

  ** Read entities by id or filter; see `ph.api::Funcs.phRead`
  @Api @Axon
  static Grid phRead(Grid req)
  {
    cx := curContext
    if (req.isEmpty) throw Err("Request grid is empty")

    if (req.has("filter"))
    {
      reqRow := req.first
      filter := Filter.fromStr(reqRow->filter)
      opts   := reqRow
      return cx.db.readAll(filter, opts)
    }

    if (req.has("id"))
    {
      return cx.db.readByIds(req.ids, false)
    }

    throw Err("Request grid missing id or filter col")
  }

//////////////////////////////////////////////////////////////////////////
// Nav
//////////////////////////////////////////////////////////////////////////

  ** Navigate the project tree; see `ph.api::Funcs.phNav`
  @Api @Axon
  static Grid phNav(Grid req)
  {
    cx := curContext

    // check if we have nav function defined and if so use it
    func := cx.resolveTopFn("nav", false)
    if (func != null) return func.call(cx, [req])

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

  ** Read history data for one or more points; see `ph.api::Funcs.phHisRead`
  @Api @Axon
  static Grid phHisRead(Grid req)
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

  ** Write history data to one or more points; see `ph.api::Funcs.phHisWrite`
  @Api @Axon
  static Grid phHisWrite(Grid req)
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

  ** Read or write a writable point's priority array; see `ph.api::Funcs.phPointWrite`
  @Api @Axon
  static Grid phPointWrite(Grid req)
  {
    cx := curContext

    // parse request
    if (req.size != 1) throw Err("Request grid must have 1 row")
    reqRow := req.first
    rec := cx.db.readById(reqRow.id)

    // if reading level will be null
    level := reqRow["level"] as Number
    if (level == null) return cx.rt.exts.point.pointArray(rec)

    // handle write
    cx.checkAdmin("pointWrite op")
    val := reqRow["val"]
    who := reqRow["who"]?.toStr ?: cx.user.dis
    dur := reqRow["duration"] as Number

    who = "Haystack.pointWrite | $who"

    // if have timed override
    if (val != null && level.toInt == 8 && dur != null)
      val = Etc.dict2("val", val, "duration", dur.toDuration)

    cx.rt.exts.point.pointWrite(rec, val, level.toInt, who).get(30sec)
    return Etc.makeEmptyGrid(Etc.dict1("ok", Marker.val))
  }

//////////////////////////////////////////////////////////////////////////
// Watches
//////////////////////////////////////////////////////////////////////////

  ** Subscribe entities to a watch; see `ph.api::Funcs.phWatchSub`
  @Api @Axon
  static Grid phWatchSub(Grid req)
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

  ** Unsubscribe entities from a watch; see `ph.api::Funcs.phWatchUnsub`
  @Api @Axon
  static Grid phWatchUnsub(Grid req)
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

  ** Poll a watch for changed entities; see `ph.api::Funcs.phWatchPoll`
  @Api @Axon
  static Grid phWatchPoll(Grid req)
  {
    cx := curContext

    // parse request
    watchId := req.meta["watchId"] as Str ?: throw Err("Missing meta.watchId")
    refresh := req.meta.has("refresh")
    curValSub := req.meta.has("curValSub")

    // poll as refresh or cov
    watch := cx.rt.watch.get(watchId)
    recs := refresh ? watch.poll(Duration.defVal) : watch.poll
    resMeta := Etc.dict1("watchId", watchId)
    if (curValSub)
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

