//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Jan 2012  Brian Frank  Creation
//   17 Jul 2012  Brian Frank  Move to connExt framework
//   02 Oct 2012  Brian Frank  New Haystack 2.0 REST API
//   29 Dec 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using xeto
using haystack
using folio
using hx
using hxConn

**
** Dispatch callbacks for the Haystack connector
**
class HaystackDispatch : ConnDispatch
{
  new make(Obj arg)  : super(arg) {}

//////////////////////////////////////////////////////////////////////////
// Receive
//////////////////////////////////////////////////////////////////////////

  override Obj? onReceive(HxMsg msg)
  {
    msgId := msg.id
    if (msgId === "call")         return onCall(msg.a, msg.b, msg.c)
    if (msgId === "readById")     return onReadById(msg.a, msg.b)
    if (msgId === "readByIds")    return onReadByIds(msg.a, msg.b)
    if (msgId === "read")         return onRead(msg.a, msg.b)
    if (msgId === "readAll")      return onReadAll(msg.a)
    if (msgId === "eval")         return onEval(msg.a, msg.b)
    if (msgId === "hisRead")      return onHisRead(msg.a, msg.b)
    if (msgId === "invokeAction") return onInvokeAction(msg.a, msg.b, msg.c)
    return super.onReceive(msg)
  }

//////////////////////////////////////////////////////////////////////////
// Open/Ping/Close
//////////////////////////////////////////////////////////////////////////

  override Void onOpen()
  {
    // gather configuration
    uriVal := rec["uri"] ?: throw FaultErr("Missing 'uri' tag")
    uri    := uriVal as Uri ?: throw FaultErr("Type of 'uri' must be Uri, not $uriVal.typeof.name")
    user   := rec["username"] as Str ?: ""
    pass   := db.passwords.get(id.toStr) ?: ""

    // open client
    opts := ["log":trace.asLog, "timeout":conn.timeout]
    client = Client.open(uri, user, pass, opts)
  }

  override Void onClose()
  {
    old := client
    client = null
    watchClear
    if (old != null && rec.missing("haystackCloseUnsupported"))
    {
      try
        old.close
      catch (Err e)
        {} // ignore for now since the close op is new
    }
  }

  override Dict onPing()
  {
    // call "about" operation
    about := client.about

    // update tags
    tags := Str:Obj[:]
    tags.addNotNull("productName",    about["productName"] as Str)
    tags.addNotNull("productVersion", about["productVersion"] as Str)
    tags.addNotNull("moduleName",     about["moduleName"] as Str)
    tags.addNotNull("moduleVersion",  about["moduleVersion"] as Str)
    tags.addNotNull("vendorName",     about["vendorName"] as Str)
    tags.addNotNull("serialNumber",   about["serialNumber"] as Str)
    about.each |v, n| { if (n.startsWith("host")) tags[n] = v }

    // update tz
    tzStr := about["tz"] as Str
    if (tzStr != null)
    {
      tz := TimeZone.fromStr(tzStr, false)
      if (tz != null) tags["tz"] = tz.name
    }

    return Etc.makeDict(tags)
  }

//////////////////////////////////////////////////////////////////////////
// Call
//////////////////////////////////////////////////////////////////////////

  Grid onCall(Str op, Grid req, Bool checked)
  {
    call(op, req, checked)
  }

  Grid call(Str op, Grid req, Bool checked := true)
  {
    openClient.call(op, req, checked)
  }

  Client openClient()
  {
    open
    return client
  }

//////////////////////////////////////////////////////////////////////////
// Client Axon Functions
//////////////////////////////////////////////////////////////////////////

  Obj? onReadById(Obj id, Bool checked)
  {
    openClient.readById(id, checked)
  }

  Obj? onReadByIds(Obj[] ids, Bool checked)
  {
    openClient.readByIds(ids, checked)
  }

  Obj? onRead(Str filter, Bool checked)
  {
    openClient.read(filter, checked)
  }

  Obj? onReadAll(Str filter)
  {
    openClient.readAll(filter)
  }

  Obj? onEval(Str expr, Dict opts)
  {
    req := Etc.makeListGrid(opts, "expr", null, [expr])
    return openClient.call("eval", req)
  }

  Obj? onInvokeAction(Obj id, Str action, Dict args)
  {
    req := Etc.makeDictGrid(["id":id, "action":action], args)
    return openClient.call("invokeAction", req)
  }

//////////////////////////////////////////////////////////////////////////
// Learn
//////////////////////////////////////////////////////////////////////////

  override Grid onLearn(Obj? arg)
  {
    // lazily build and cache noLearnTags using FolioUtil
    noLearnTags := noLearnTagsRef.val as Dict
    if (noLearnTags == null)
    {
      noLearnTagsRef.val = noLearnTags = Etc.makeDict(FolioUtil.tagsToNeverLearn)
    }

    client := openClient
    req := arg == null ? Etc.makeEmptyGrid : Etc.makeListGrid(null, "navId", null, [arg])
    res := client.call("nav", req)

    learnRows := Str:Obj?[,]
    res.each |row|
    {
      // map tags
      map := Str:Obj[:]
      row.each |val, name|
      {
        if (val is Bin) return
        if (val is Ref) return
        if (noLearnTags.has(name)) return
        map[name] = val
      }

      // make sure we have dis column
      id := row["id"] as Ref
      if (map["dis"] == null)
      {
        if (row.has("navName"))
          map["dis"] = row["navName"].toStr
        else if (id != null)
          map["dis"] = id.dis
      }

      // map addresses as either point leaf or nav node
      if (row.has("point"))
      {
        if (id != null)
        {
          if (row.has("cur"))      map["haystackCur"]   = id.toStr
          if (row.has("writable")) map["haystackWrite"] = id.toStr
          if (row.has("his"))      map["haystackHis"]   = id.toStr
        }
      }
      else
      {
        navId := row["navId"]
        if (navId != null) map["learn"] = navId
      }

      // learn row
      learnRows.add(map)
    }
    return Etc.makeMapsGrid(null, learnRows)
  }

  private static const AtomicRef noLearnTagsRef := AtomicRef()

//////////////////////////////////////////////////////////////////////////
// Sync Cur
//////////////////////////////////////////////////////////////////////////

  override Void onSyncCur(ConnPoint[] points)
  {
    // map to batch read
    ids := Obj[,]
    pointsByIndex := ConnPoint[,]
    points.each |pt|
    {
      try
      {
        id := toCurId(pt)
        ids.add(id)
        pointsByIndex.add(pt)
      }
      catch (Err e) pt.updateCurErr(e)
    }
    if (ids.isEmpty) return

    // use watchSub to temp refresh the points
    reqMeta := [
      "watchDis":"SkySpark Conn: $dis (sync cur)",
      "lease": Number(10sec, null),
      "curValPoll": Marker.val]
    req := Etc.makeListGrid(reqMeta, "id", null, ids)
    readGrid := call("watchSub", req)

    // update point status based on result
    readGrid.each |readRow, i|
    {
      pt := pointsByIndex[i]
      syncPoint(pt, readRow)
    }
  }

  private Void syncPoint(ConnPoint pt, Dict result)
  {
    if (result.missing("id"))
    {
      pt.updateCurErr(UnknownRecErr(""))
      return
    }

    curStatus := result["curStatus"] as Str
    if (curStatus != null && curStatus != "ok")
    {
      errStatus := ConnStatus.fromStr(curStatus, false) ?: ConnStatus.fault
      pt.updateCurErr(RemoteStatusErr(errStatus))
      return
    }

    pt.updateCurOk(result["curVal"])
  }

//////////////////////////////////////////////////////////////////////////
// Watches
//////////////////////////////////////////////////////////////////////////

  override Void onWatch(ConnPoint[] points)
  {
    try
      watchSub(points)
    catch (Err e)
      onWatchErr(e)
  }

  ** Implementation shared by onWatchErr to re-subscribe everything
  private Void watchSub(ConnPoint[] points)
  {
    // map points to their haystackCur
    subIds := Obj[,]; subIds.capacity = points.size
    subPoints := ConnPoint[,]; subPoints.capacity = points.size
    points.each |pt|
    {
      try
      {
        id := toCurId(pt)
        subIds.add(id)
        subPoints.add(pt)
      }
      catch (Err e) pt.updateCurErr(e)
    }

    // if nothing with valid haystackCur id, short circuit
    if (subIds.isEmpty) return

    // ask for a lease period at least 2 times longer than poll freq
    leaseReq := (conn.pollFreq ?: 10sec) * 2
    if (leaseReq < 1min) leaseReq = 1min

    // make request for subscription
    meta := [
      "watchDis":"SkySpark Conn: $dis",
      "lease": Number(leaseReq, null),
      "curValSub": Marker.val]
    if (watchId != null) meta["watchId"] = watchId
    req := Etc.makeListGrid(meta, "id", null, subIds)

    // make the call
    res := call("watchSub", req)

    // save away my watchId
    watchId := res.meta->watchId
    watchLeaseReq := leaseReq
    watchLeaseRes := null
    try
      watchLeaseRes = ((Number)res.meta->lease).toDuration
    catch (Err e)
      watchLeaseRes = e.toStr
    watchInfo = WatchInfo(watchId, watchLeaseReq, watchLeaseRes)
    setConnData(watchInfo)

    // now match up response
    res.each |resRow, i|
    {
      // match response row to point
      pt := subPoints.getSafe(i)
      if (pt == null) return

      // map id in response to the one we'll be getting in polls
      id := resRow["id"]
      if (id != null) addWatchedId(id, pt)

      // sync up the point
      syncPoint(pt, resRow)
    }
  }

  ** Map watched id to given pt.  In the case of multiple points with
  ** duplicated haystackCur tags we might store with a ConnPoint or
  ** a ConnPoint[] for each id key in the hashmap
  private Void addWatchedId(Obj id, ConnPoint pt)
  {
    // 99% case is we are adding it fresh
    cur := watchedIds[id]
    if (cur == null) { watchedIds[id] = pt; return }

    // if we have an existing point, then turn it into a list
    curPt := cur as ConnPoint
    if (curPt != null)
    {
      if (cur === pt) return
      watchedIds[id] = ConnPoint[curPt, pt]
      return
    }

    // triple mapped points
    curList := cur as ConnPoint[] ?: throw Err("expecting ConnPoint[], not $cur.typeof")
    if (curList.indexSame(pt) != null) return
    curList.add(pt)
  }

  override Void onUnwatch(ConnPoint[] points)
  {
    // map uris
    ids := Obj[,]
    points.each |pt|
    {
      try
      {
        id := toCurId(pt)
        ids.add(id)
      }
      catch (Err e) {}
    }

    // if we don't have a watch, nothing left to do
    if (watchId == null) return

    // make unsubscribe request
    close := !hasPointsWatched
    meta := Str:Obj["watchId": watchId]
    if (close) meta["close"] = Marker.val
    req := Etc.makeListGrid(meta, "id", null, ids)

    // make REST call
    try
      call("watchUnsub", req)
    catch (Err e)
      {}

    // if no more points in watch, close watch
    if (close) watchClear
  }

  override Void onPollManual()
  {
    if (watchId == null) return
    try
    {
      req := Etc.makeEmptyGrid(Etc.dict2("watchId", watchId, "curValSub", Marker.val))
      res := call("watchPoll", req)
      res.each |rec|
      {
        id := rec["id"] ?: Ref.nullRef
        ptOrPts := watchedIds[id]
        if (ptOrPts == null)
        {
          if (id != Ref.nullRef) echo("WARN: HaystackConn watch returned unwatched point: $id")
          return
        }
        if (ptOrPts is ConnPoint)
          syncPoint(ptOrPts, rec)
        else
          ((ConnPoint[])ptOrPts).each |pt| { syncPoint(pt, rec) }
      }
    }
    catch (Err e) onWatchErr(e)
  }

  private Void onWatchErr(Err err)
  {
    // clear watch data structures
    watchClear

    if (err is CallErr)
    {
       // try to reopen the watch
       try
         watchSub(pointsWatched)
       catch (Err e)
         {}
    }

    // assume network problem and close the connection
    close(err)
  }

  private Str? watchId () { watchInfo?.id }

  private Void watchClear()
  {
    this.watchInfo = null
    this.watchedIds.clear
  }

//////////////////////////////////////////////////////////////////////////
// Writes
//////////////////////////////////////////////////////////////////////////

  override Void onWrite(ConnPoint point, ConnWriteInfo info)
  {
    val   := info.val
    level := info.level
    who   := info.who

    try
    {
      // get haystackWrite address
      id := toWriteId(point)

      // get write level
      writeLevel := toHaystackWriteLevel(point, info)
      if (writeLevel == null) return

      // check if we've changed the write level and if so, then
      // write null to the old level
      lastWriteLevel := point.data as Number
      if (lastWriteLevel != null && lastWriteLevel != writeLevel)
        callPointWrite(point, id, lastWriteLevel, null, null)

      // if tuning has writeSchedule and who is a schedule grid
      Str? schedule
      timeline := info.opts["schedule"]
      if (timeline is Grid && point.tuning.rec.has("writeSchedule"))
        schedule = ZincWriter.gridToStr(timeline)

      // make REST call
      callPointWrite(point, id, writeLevel, val, schedule)
      setPointData(point, writeLevel)
      point.updateWriteOk(info)
    }
    catch (Err e)
    {
      point.updateWriteErr(info, e)
    }
  }

  private Grid callPointWrite(ConnPoint point, Obj id, Number writeLevel, Obj? val, Str? schedule)
  {
    reqWho := "$proj.name :: $point.dis"
    map := ["id":id, "level":writeLevel, "who":reqWho]
    if (val != null) map["val"] = val
    if (schedule != null) map["schedule"] = schedule
    req := Etc.makeMapGrid(null, map)
    return call("pointWrite", req)
  }

  private Number? toHaystackWriteLevel(ConnPoint pt, ConnWriteInfo info)
  {
    // if no level
    x := pt.rec["haystackWriteLevel"]
    if (x == null)
    {
      pt.updateWriteErr(info, FaultErr("missing haystackWriteLevel"));
      return null
    }

    // sanity on value
    num := x as Number
    if (num == null)
    {
      pt.updateWriteErr(info, FaultErr("haystackWriteLevel is $x.typeof.name not Number"));
      return null
    }

    if (num.toInt < 1 || num.toInt > 17)
    {
      pt.updateWriteErr(info, FaultErr("haystackWriteLevel is not 1-17: $num"));
      return null
    }

    return num
  }

//////////////////////////////////////////////////////////////////////////
// History
//////////////////////////////////////////////////////////////////////////

  Grid onHisRead(Ref id, Str range)
  {
    req := GridBuilder().addCol("id").addCol("range").addRow2(id, range).toGrid
    return openClient.call("hisRead", req)
  }

  override Obj? onSyncHis(ConnPoint point, Span span)
  {
    try
    {
      // serialize range into REST Str format
      tz := point.tz
      range := "$span.start,$span.end"

      // build request grid
      hisId := toHisId(point)
      req := GridBuilder().addCol("id").addCol("range").addRow2(hisId, range).toGrid

      // make REST call
      res := openClient.call("hisRead", req)

      // turn into his items
      items := HisItem[,]
      items.capacity = res.size
      ts  := res.col("ts")
      val := res.col("val")
      res.each |row| { items.add(HisItem(row.val(ts), row.val(val))) }

      // we are good!
      return point.updateHisOk(items, span)
    }
    catch (Err e)
    {
      return point.updateHisErr(e)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Addressing
//////////////////////////////////////////////////////////////////////////

  private static Ref toCurId(ConnPoint pt) { toRemoteId(pt.curAddr) }

  private static Ref toWriteId(ConnPoint pt) { toRemoteId(pt.writeAddr) }

  private static Ref toHisId(ConnPoint pt) { toRemoteId(pt.hisAddr) }

  private static Ref toRemoteId(Obj val) { Ref.make(val.toStr, null) }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Client? client
  private Obj:Obj watchedIds := [:]  // ConnPoint or ConnPoint[]
  private WatchInfo? watchInfo
}

**************************************************************************
** WatchInfo
**************************************************************************

internal const class WatchInfo
{
  new make(Str id, Duration leaseReq, Obj leaseRes)
  {
    this.id       = id
    this.leaseReq = leaseReq
    this.leaseRes = leaseRes
  }

  const Str id               // if we have watch open
  const Duration leaseReq    // requested lease time
  const Obj leaseRes         // response lease time as Duration or Err str

  override Str toStr() { "WatchInfo $id" }
}

