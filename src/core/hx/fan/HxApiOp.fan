//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jun 2021  Brian Frank  Creation
//

using concurrent
using web
using haystack
using axon
using folio

**
** Base class for HTTP API operation processing
**
abstract class HxApiOp
{
  ** Subclasses must declare public no-arg constructor
  new make()
  {
    this.spiRef = Actor.locals["hxApiOp.spi"] as HxApiOpSpi ?: throw Err("Invalid make context")
  }

  ** Programmatic name of the op
  Str name() { spi.name }

  ** Op definition
  Def def() { spi.def }

  ** Process an HTTP service call to this op
  virtual Void onService(WebReq req, WebRes res, HxContext cx)
  {
    // parse request grid; if readReq returns null
    // then an error has already been returned
    reqGrid := spi.readReq(this, req, res)
    if (reqGrid == null) return

    // subclass hook
    resGrid := onRequest(reqGrid, cx)

    // respond with resulting grid
    spi.writeRes(this, req, res, resGrid)
  }

  ** Process parsed request.  Default implentation
  ** attempts to eval an Axon function of the same name.
  abstract Grid onRequest(Grid req, HxContext cx)

  ** Return if this operation can be called with GET method.
  @NoDoc virtual Bool isGetAllowed()
  {
    def.has("noSideEffects")
  }

  ** Service provider interface
  @NoDoc virtual HxApiOpSpi spi() { spiRef }
  @NoDoc const HxApiOpSpi spiRef
}

**************************************************************************
** HxApiOpSpi
**************************************************************************

**
** HxApiOp service provider interface
**
@NoDoc
const mixin HxApiOpSpi
{
  abstract Str name()
  abstract Def def()
  abstract Grid? readReq(HxApiOp op, WebReq req, WebRes res)
  abstract Void writeRes(HxApiOp op, WebReq req, WebRes res, Grid result)
}

**************************************************************************
** HxAboutOp
**************************************************************************

internal class HxAboutOp : HxApiOp
{
  override Grid onRequest(Grid req, HxContext cx)
  {
    Etc.makeDictGrid(null, HxCoreFuncs.about)
  }
}

**************************************************************************
** HxDefsOp
**************************************************************************

internal class HxDefsOp : HxApiOp
{
  override Grid onRequest(Grid req, HxContext cx)
  {
    opts := req.first as Dict ?: Etc.emptyDict
    limit := (opts["limit"] as Number)?.toInt ?: Int.maxVal
    filter := Filter.fromStr(opts["filter"] as Str ?: "", false)
    acc := Def[,]
    incomplete := false
    eachDef(cx) |def|
    {
      if (filter != null && !filter.matches(def, cx)) return
      if (acc.size >= limit) { incomplete = true; return }
      acc.add(def)
    }
    meta := incomplete ? Etc.makeDict2("incomplete", Marker.val, "limit", Number(limit)) : Etc.emptyDict
    return Etc.makeDictsGrid(meta, acc)
  }

  virtual Void eachDef(HxContext cx, |Def| f) { cx.ns.eachDef(f) }
}

**************************************************************************
** HxFiletypesOp
**************************************************************************

internal class HxFiletypesOp : HxDefsOp
{
  override Void eachDef(HxContext cx, |Def| f) { cx.ns.filetypes.each(f) }
}

**************************************************************************
** HxLibsOp
**************************************************************************

internal class HxLibsOp : HxDefsOp
{
  override Void eachDef(HxContext cx, |Def| f) { cx.ns.libsList.each(f) }
}

**************************************************************************
** HxOpsOp
**************************************************************************

internal class HxOpsOp : HxDefsOp
{
  override Void eachDef(HxContext cx, |Def| f) { cx.ns.feature("op").eachDef(f) }
}

**************************************************************************
** HxReadOp
**************************************************************************

internal class HxReadOp : HxApiOp
{
  override Grid onRequest(Grid req, HxContext cx)
  {
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
}

**************************************************************************
** HxEvalOp
**************************************************************************

internal class HxEvalOp : HxApiOp
{
  override Grid onRequest(Grid req, HxContext cx)
  {
    if (req.isEmpty) throw Err("Request grid is empty")
    expr := (Str)req.first->expr
    return Etc.toGrid(cx.evalOrReadAll(expr))
  }
}

**************************************************************************
** HxCommitOp
**************************************************************************

internal class HxCommitOp : HxApiOp
{
  override Grid onRequest(Grid req, HxContext cx)
  {
    if (!cx.user.isAdmin) throw PermissionErr("Missing 'admin' permission: commit")
    mode := req.meta->commit
    switch (mode)
    {
      case "add":    return onAdd(req, cx)
      case "update": return onUpdate(req, cx)
      case "remove": return onRemove(req, cx)
      default:       throw ArgErr("Unknown commit mode: $mode")
    }
  }

  private Grid onAdd(Grid req, HxContext cx)
  {
    diffs := Diff[,]
    req.each |row|
    {
      changes := Str:Obj?[:]
      Ref? id := null
      row.each |v, n|
      {
        if (v == null) return
        if (n == "id") { id = v; return }
        changes.add(n, v)
      }
      diffs.add(Diff.makeAdd(changes, id ?: Ref.gen))
    }
    newRecs := cx.db.commitAll(diffs).map |d->Dict| { d.newRec }
    return Etc.makeDictsGrid(null, newRecs)
  }

  private Grid onUpdate(Grid req, HxContext cx)
  {
    flags := 0
    if (req.meta.has("force"))     flags = flags.or(Diff.force)
    if (req.meta.has("transient")) flags = flags.or(Diff.transient)

    diffs := Diff[,]
    req.each |row|
    {
      old := Etc.makeDict(["id":row.id, "mod":row->mod])
      changes := Str:Obj?[:]
      row.each |v, n|
      {
        if (v == null) return
        if (n == "id" || n == "mod") return
        changes.add(n, v)
      }
      diffs.add(Diff(old, changes, flags))
    }
    newRecs := cx.db.commitAll(diffs).map |d->Dict| { d.newRec }
    return Etc.makeDictsGrid(null, newRecs)
  }

  private Grid onRemove(Grid req, HxContext cx)
  {
    flags := Diff.remove
    if (req.meta.has("force")) flags = flags.or(Diff.force)

    diffs := Diff[,]
    req.each |row| { diffs.add(Diff(row, null, flags)) }
    cx.db.commitAll(diffs)
    return Etc.makeEmptyGrid
  }
}

**************************************************************************
** HxHisReadOp
**************************************************************************

internal class HxHisReadOp : HxApiOp
{
  override Grid onRequest(Grid req, HxContext cx)
  {
    // parse request
    if (req.isEmpty) throw Err("Request grid is empty")
    reqRow := req.first
    rec := cx.db.readById(reqRow.id)
    tz := FolioUtil.hisTz(rec)
    span := parseRange(tz, reqRow->range)

    // convert timezones if needed so that clients are
    // free to request/convert the timezone as they see fit
    span = span.toTimeZone(tz)

    // query items
    meta := [
      "id": rec.id,
      "hisStart": span.start,
      "hisEnd": span.end
    ]

    gb := GridBuilder().setMeta(meta).addCol("ts").addCol("val")
    cx.rt.his.read(rec, span, req.meta) |item|
    {
      if (item.ts < span.start) return
      if (item.ts >= span.end) return
      gb.addRow2(item.ts, item.val)
    }
    return gb.toGrid
  }

  static Span? parseRange(TimeZone tz, Str q)
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
      return null
    }
    catch (Err e) throw ParseErr("Invalid history range: $q", e)
  }
}

//////////////////////////////////////////////////////////////////////////
// HisWrite
//////////////////////////////////////////////////////////////////////////

internal class HxHisWriteOp : HxApiOp
{
  override Grid onRequest(Grid req, HxContext cx)
  {
    // check security
    cx.checkAdmin("hisWrite op")

    // lookup history record
    rec := cx.db.readById(req.meta.id)

    // map request grid to HisItem
    items := HisItem[,] { capacity = req.size }
    tsCol := req.col("ts")
    valCol := req.col("val")
    req.each |row|
    {
      tsRaw := row.val(tsCol)
      ts := tsRaw as DateTime ?: throw Err("Timestamp value is not DateTime: $tsRaw [${tsRaw?.typeof}]")
      val := row.val(valCol)
      items.add(HisItem(ts, val))
    }

    // perform write
    opts := req.meta
    cx.rt.his.write(rec, items, opts)

    return Etc.makeEmptyGrid(Etc.makeDict1("ok", Marker.val))
  }
}

**************************************************************************
** HxPointWriteOp
**************************************************************************

internal class HxPointWriteOp : HxApiOp
{
  override Grid onRequest(Grid req, HxContext cx)
  {
    // parse request
    if (req.size != 1) throw Err("Request grid must have 1 row")
    reqRow := req.first
    rec := cx.db.readById(reqRow.id)

    // if reading level will be null
    level := reqRow["level"] as Number
    if (level == null) return cx.rt.pointWrite.array(rec)

    // handlw write
    cx.checkAdmin("pointWrite op")
    val := reqRow["val"]
    who := reqRow["who"]?.toStr ?: cx.user.dis
    dur := reqRow["duration"] as Number

    who = "Haystack.pointWrite | $who"

    // if have timed override
    if (val != null && level.toInt == 8 && dur != null)
      val = Etc.makeDict2("val", val, "duration", dur.toDuration)

    cx.rt.pointWrite.write(rec, val, level.toInt, who).get(30sec)
    return Etc.makeEmptyGrid(Etc.makeDict1("ok", Marker.val))
  }
}


