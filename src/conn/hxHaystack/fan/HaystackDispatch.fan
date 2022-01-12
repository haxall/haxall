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
    if (msgId === "call")         return onCall(msg.a, ((Unsafe)msg.b).val, msg.c)
    if (msgId === "readById")     return onReadById(msg.a, msg.b)
    if (msgId === "readByIds")    return onReadByIds(msg.a, msg.b)
    if (msgId === "read")         return onRead(msg.a, msg.b)
    if (msgId === "readAll")      return onReadAll(msg.a)
    if (msgId === "eval")         return onEval(msg.a, msg.b)
//    if (msgId === "hisRead")      return onHisRead(msg.a, msg.b)
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
    client = null
    // TODO
    //watchClear
  }

  override Dict onPing()
  {
    // call "about" operation
    about := client.about

    // update tags
    tags := Str:Obj[:]
    if (about["productName"]    is Str) tags["productName"]    = about->productName
    if (about["productVersion"] is Str) tags["productVersion"] = about->productVersion
    if (about["vendorName"]     is Str) tags["vendorName"]     = about->vendorName
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

  Unsafe onCall(Str op, Grid req, Bool checked)
  {
    Unsafe(call(op, req, checked))
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
    try
      return openClient.readById(id, checked)
    catch (Err err)
      return err
  }

  Obj? onReadByIds(Obj[] ids, Bool checked)
  {
    try
      return Unsafe(openClient.readByIds(ids, checked))
    catch (Err err)
      return err
  }

  Obj? onRead(Str filter, Bool checked)
  {
    try
      return openClient.read(filter, checked)
    catch (Err err)
      return err
  }

  Obj? onReadAll(Str filter)
  {
    try
      return Unsafe(openClient.readAll(filter))
    catch (Err err)
      return err
  }

  Obj? onEval(Str expr, Dict opts)
  {
    try
    {
      req := Etc.makeListGrid(opts, "expr", null, [expr])
      return Unsafe(openClient.call("eval", req))
    }
    catch (Err err) return err
  }

  Obj? onInvokeAction(Obj id, Str action, Dict args)
  {
    req := Etc.makeDictGrid(["id":id, "action":action], args)
    try
      return Unsafe(openClient.call("invokeAction", req))
    catch (Err err)
      return err
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
        if (val == null) return
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

  Void onSyncCur(ConnPoint[] points)
  {
    // map to batch read
    ids := Obj[,]
    pointsByIndex := ConnPoint[,]
    points.each |pt|
    {
      if (!pt.hasCur) return
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
      if (!pt.hasCur) return
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
    leaseReq := conn.pollFreq * 2
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
    this.watchId = res.meta->watchId
    this.watchLeaseReq = leaseReq
    try
      this.watchLeaseRes = ((Number)res.meta->lease).toDuration
    catch (Err e)
      this.watchLeaseRes = e.toStr

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

  override Void onPoll()
  {
    if (watchId == null) return
    try
    {
      req := Etc.makeEmptyGrid(["watchId": watchId])
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

  private Void watchClear()
  {
    this.watchId = null
    this.watchLeaseReq = null
    this.watchLeaseRes = null
    this.watchedIds.clear
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
  private Str? watchId               // if we have watch open
  private Duration? watchLeaseReq    //  request lease time
  private Obj? watchLeaseRes         // response lease time as Duration or Err str
}

