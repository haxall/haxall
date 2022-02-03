//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    1 Mar 2010  Brian Frank  Creation
//   13 Jun 2012  Brian Frank  Rewrite for connExt framework
//    3 Feb 2022  Brian Frank  Redesign for Haxall
//

using inet
using obix
using haystack
using hx
using hxConn

**
** ObixDispatch
**
class ObixDispatch : ConnDispatch
{
  new make(Obj arg) : super(arg) {}

//////////////////////////////////////////////////////////////////////////
// Messaging
//////////////////////////////////////////////////////////////////////////

  override Obj? onReceive(HxMsg msg)
  {
    msgId := msg.id
    if (msgId === "readHis")   return onReadHis(msg.a, msg.b)
    if (msgId === "readObj")   return onReadObj(msg.a)
    if (msgId === "writeObj")  return onWriteObj(msg.a, msg.b)
    if (msgId === "invoke")    return onInvoke(msg.a, msg.b)
    return super.onReceive(msg)
  }

//////////////////////////////////////////////////////////////////////////
// Connection
//////////////////////////////////////////////////////////////////////////

  override Void onOpen()
  {
    // gather configuration
    lobbyVal := rec["obixLobby"] ?: throw FaultErr("Missing 'obixLobby' tag")
    lobbyUri := lobbyVal as Uri ?: throw FaultErr("Type of 'obixLobby' must be Uri, not $lobbyVal.typeof.name")
    user     := rec["username"] ?: ""
    pass     := db.passwords.get(id.toStr) ?: ""

    // open the client
    client = ObixClient(lobbyUri, user, pass)
    client.log = this.log
    client.socketConfig = SocketConfig.cur.setTimeouts(conn.timeout)
    client.readLobby
    isNiagara = rec.get("productName", "").toStr.contains("Niagara")
  }

  override Void onClose()
  {
    // try to close watch to gracefully cleanup
    try clientWatch?.close; catch {}

    // null out everything
    client = null
    clientWatch = null
    watchUris.clear
  }

  override Dict onPing()
  {
    // read about
    about := client.readAbout

    // map about to ping tags
    tags := Str:Obj[:]

    // update tz if valid
    tzStr := ObixUtil.toChildVal(about, "tz") as Str
    if (tzStr != null)
    {
      tz := TimeZone.fromStr(tzStr, false)
      if (tz != null) tags["tz"] = tz.name
    }

    // vendor/product
    tags["productName"]    = ObixUtil.toChildVal(about, "productName", "?")
    tags["productVersion"] = ObixUtil.toChildVal(about, "productVersion", "?")
    tags["vendorName"]     = ObixUtil.toChildVal(about, "vendorName", "?")

    return Etc.makeDict(tags)
  }

//////////////////////////////////////////////////////////////////////////
// Reads/Learn
//////////////////////////////////////////////////////////////////////////

  private Obj? onReadObj(Uri uri)
  {
    open
    return ObixUtil.toGrid(this, client.read(uri))
  }

  private Obj? onWriteObj(Uri uri, Obj? val)
  {
    open
    obj := ObixUtil.toObix(val)
    obj.href = uri
    return ObixUtil.toGrid(this, client.write(obj))
  }

  private Obj? onInvoke(Uri uri, Obj? val)
  {
    open
    return ObixUtil.toGrid(this, client.invoke(uri, ObixUtil.toObix(val)))
  }

  override Grid onLearn(Obj? obj)
  {
    ObixLearn(this, obj).learn
  }

//////////////////////////////////////////////////////////////////////////
// Points
//////////////////////////////////////////////////////////////////////////

  ** Callback for obixSyncCur
  override Void onSyncCur(ConnPoint[] points)
  {
    // map to batch read
    uris := Uri[,]
    pointsByIndex := ConnPoint[,]
    points.each |pt|
    {
      uri := toObixCur(pt)
      if (uri == null) return
      uris.add(uri)
      pointsByIndex.add(pt)
    }
    if (uris.isEmpty) return

    // make batch read
    objs := client.batchRead(uris)
    objs.each |obj, i|
    {
      pt := pointsByIndex[i]
      syncPoint(pt, obj)
    }
  }

  private Uri? toObixCur(ConnPoint pt)
  {
    // skip if no current address
    uriVal := pt.rec["obixCur"]
    if (uriVal == null) return null

    // sanity on uri value
    uri := uriVal as Uri
    if (uri == null)
    {
      pt.updateCurErr(Err("obixCur is $uriVal.typeof.name not Uri"));
      return null
    }

    return uri
  }

  ** Callback for watch, do subscription on comp
  override Void onWatch(ConnPoint[] points)
  {
    // map uris
    uris := Uri[,]
    points.each |pt|
    {
      uri := toObixCur(pt)
      if (uri == null) return
      uris.add(uri)
      watchUris[uri] = pt
    }

    // if no uris or no watch service, short circuit
    if (uris.isEmpty) return
    if (client.watchServiceUri == null) return

    try
    {
      // lazily open watch
      if (clientWatch == null) clientWatch = client.watchOpen

      // add URIs to watch and sync response
      syncWatched(clientWatch.add(uris))
    }
    catch (ObixErr e) onWatchErr(e)
  }

  override Void onUnwatch(ConnPoint[] points)
  {
    // map uris
    uris := Uri[,]
    points.each |pt|
    {
      uri := pt.rec["obixCur"] as Uri
      if (uri == null) return
      uris.add(uri)
      watchUris.remove(uri)
    }

    // if we don't have a watch, nothing left to do
    if (clientWatch == null) return

    // remove URIs
    try
      clientWatch.remove(uris)
    catch (Err e)
      {}

    // if no more points in watch, close watch
    if (watchUris.isEmpty)
    {
      cw := clientWatch
      clientWatch = null
      cw.close
    }
  }

  override Void onPollManual()
  {
    if (clientWatch == null) return
    try
      syncWatched(clientWatch.pollChanges)
    catch (Err e)
      onWatchErr(e)
  }

  private Void onWatchErr(Err err)
  {
    if (err is ObixErr && ((ObixErr)err).isBadUri)
    {
       // try to reopen the watch
       try
       {
         clientWatch = client.watchOpen
         syncWatched(clientWatch.add(watchUris.keys))
         return
       }
       catch (Err e) {}
    }

    // assume network problem and close the connection
    close(err)
  }

  private Void syncWatched(ObixObj[] objs)
  {
    objs.each |obj|
    {
      pt := watchUris[obj.href]
      if (pt == null) return
      syncPoint(pt, obj)
    }
  }

  private Void syncPoint(ConnPoint pt, ObixObj obj)
  {
    if (obj.elemName == "err")
    {
      pt.updateCurErr(ObixErr(obj))
      return
    }

    errStatus := toCurErrStatus(obj.status)
    if (errStatus != null)
    {
      pt.updateCurErr(RemoteStatusErr(errStatus))
      return
    }

    val := obj.val
    if (val is Num) val = Number.makeNum(val, obj.unit)

     pt.updateCurOk(val)
  }

  private ConnStatus? toCurErrStatus(Status obixStatus)
  {
    switch (obixStatus)
    {
      case Status.down:     return ConnStatus.down
      case Status.fault:    return ConnStatus.fault
      case Status.disabled: return ConnStatus.disabled
      default:              return null
    }
  }

//////////////////////////////////////////////////////////////////////////
// Writes
//////////////////////////////////////////////////////////////////////////

  override Void onWrite(ConnPoint pt, ConnWriteInfo info)
  {
    uri := pt.rec["obixWrite"] as Uri ?: throw FaultErr("Missing obixWrite Uri")

    // build <obj is='obix:WritePointIn'><obj name='value'/></obj>
    valObj := ObixUtil.toObix(info.val)
    valObj.name = "value"
    arg := ObixObj() { contract = Contract.writePointIn; add(valObj) }

    // make the request
    client.invoke(uri, arg)

    // if request didn't raise an exception we must be good!
    pt.updateWriteOk(info)
  }

//////////////////////////////////////////////////////////////////////////
// His
//////////////////////////////////////////////////////////////////////////

  override Obj? onSyncHis(ConnPoint point, Span span)
  {
    try
      return point.updateHisOk(onReadHis(point.rec->obixHis, span), span)
    catch (Err e)
      return point.updateHisErr(e)
  }

  private Obj? onReadHis(Uri uri, Span span)
  {
    try
      return readHisUri(uri, span.start, span.end)
    catch (Err err)
      return err
  }

  private HisItem[] readHisUri(Uri uri, DateTime? start, DateTime? end, TimeZone? tz := null)
  {
    open
    return readHis(client.read(uri), start, end, tz)
  }

  private HisItem[] readHis(ObixObj hisObj, DateTime? start, DateTime? end, TimeZone? tz := null)
  {
    Uri? queryUri
    try
    {
      queryUri = hisObj.href + hisObj.get("query").href
    }
    catch (Err e)
    {
      s := StrBuf()
      hisObj.writeXml(s.out)
      throw Err("Cannot access 'query' op:\n$s", e)
    }

    // build request
    req := ObixObj { contract = Contract([`obix:HistoryFilter`]) }
    if (start != null) req.add(ObixObj { name="start"; val = start })
    if (end != null) req.add(ObixObj { name="end"; val = end })

    // invoke
    res := client.invoke(queryUri, req)
    // res.writeXml(Env.cur.out)

    // get data items
    return ObixUtil.toHisItems(res, tz)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ObixClient? client
  ObixClientWatch? clientWatch
  Uri:ConnPoint watchUris := [:]
  Bool isNiagara
}