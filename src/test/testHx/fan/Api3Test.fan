//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Jun 2021  Brian Frank  Creation
//

using concurrent
using inet
using xeto
using haystack
using auth
using axon
using hx

**
** Api3Test tests Haxall 3.x legacy Haystack HTTP API (Haystack 2.0 to 4.0)
**
class Api3Test : ApiTest
{
  @HxTestProj
  Void test()
  {
    init
    doAbout
    doRead
    doCommit
    doGets
    doNav
    doWatches
    doHis
    doPointWrite
    cleanup
  }

//////////////////////////////////////////////////////////////////////////
// About
//////////////////////////////////////////////////////////////////////////

  private Void doAbout()
  {
    verifyAbout(a)
    verifyAbout(b)
    verifyAbout(c)
  }

  private Void verifyAbout(Client c)
  {
    about := c.about
    verifyEq(about->haystackVersion,      rt.defs.lib("ph").version.toStr)
    verifyEq(about->whoami,               c.auth->user)
    verifyEq(about->tz,                   TimeZone.cur.name)
    verifyEq(about->productName,          sys.platform.productName)
    verifyEq(about->productVersion,       sys.platform.productVersion)
    verifyEq(about->vendorName,           sys.platform.vendorName)
    verifyEq(about->vendorUri,            sys.platform.vendorUri)
    verifyEq(about->serverName,           Env.cur.host)
    verifyEq(about->serverTime->date,     Date.today)
    verifyEq(about->serverBootTime->date, Date.today)
  }

//////////////////////////////////////////////////////////////////////////
// Read
//////////////////////////////////////////////////////////////////////////

  private Void doRead()
  {
    verifyAbout(a)
    verifyAbout(b)
    verifyAbout(c)
  }

  private Void verifyRead(Client c)
  {
    // readAll
    g := c.readAll("site")
    verifyDictsEq(g.toRows, [siteA, siteB, siteC], false)
    g = c.readAll("notThere")
    verifyEq(g.size, 0)

    // read ok
    dict := c.read("site")
    verifyEq(["A", "B", "C"].contains(dict.dis), true)

    // read bad
    verifyEq(c.read("notThere", false), null)
    verifyErr(UnknownRecErr#) { c.read("notThere") }

    // readById ok
    dict = c.readById(siteB.id)
    verifyDictEq(dict, siteB)

    // readById bad
    verifyEq(c.readById(Ref.gen, false), null)
    verifyErr(UnknownRecErr#) { c.readById(Ref.gen) }

    // readByIds ok
    g = c.readByIds([siteA.id, siteB.id, siteC.id])
    verifyDictsEq(g.toRows, [siteA, siteB, siteC], true)
    g = c.readByIds([siteC.id, siteB.id, siteA.id])
    verifyDictsEq(g.toRows, [siteC, siteB, siteA], true)

    // readByIds bad
    g = c.readByIds([siteA.id, siteB.id, siteC.id, Ref.gen], false)
    verifyDictsEq(g.toRows[0..2], [siteA, siteB, siteC], true)
    verifyDictEq(g[-1], Etc.emptyDict)
    verifyErr(UnknownRecErr#) { c.readByIds([siteA.id, Ref.gen]) }

    // raw read by filter
    g = c.call("read", Etc.makeMapGrid(null, ["filter":"area >= 20000"]))
    verifyDictsEq(g.toRows, [siteA, siteB], false)

    // raw read by filter with limit
    g = c.call("read", Etc.makeMapGrid(null, ["filter":"site", "limit":n(2)]))
    verifyEq(g.size, 2)

    // raw read by id
    g = c.call("read", Etc.makeListGrid(null, "id", null, [Ref.gen, siteB.id, Ref.gen, siteC.id]))
    verifyDictEq(g[0], Etc.emptyDict)
    verifyDictEq(g[1], siteB)
    verifyDictEq(g[2], Etc.emptyDict)
    verifyDictEq(g[3], siteC)
  }

//////////////////////////////////////////////////////////////////////////
// Commit
//////////////////////////////////////////////////////////////////////////

  private Void doCommit()
  {
    verifyPermissionErr { this.verifyCommit(this.a) }
    verifyCommit(b)
    verifyCommit(c)
  }

  private Void verifyCommit(Client c)
  {
    // add
    db := rt.db
    verifyEq(db.readCount(Filter("foo")), 0)
    Grid g := c.call("commit", Etc.makeMapGrid(["commit":"add"], ["dis":"Commit Test", "foo":m]))
    r := g.first as Dict
    verifyEq(db.readCount(Filter("foo")), 1)
    verifyDictEq(db.read(Filter("foo")), r)

    // update
    g = c.call("commit", Etc.makeMapGrid(["commit":"update"], ["id":r.id, "mod":r->mod, "bar":"baz"]))
    r = readById(r.id)
    verifyEq(r["bar"], "baz")
    verifyDictEq(r, g.first)

    // update transient
    g = c.call("commit", Etc.makeMapGrid(["commit":"update", "transient":m], ["id":r.id, "mod":r->mod, "curVal":n(123)]))
    r = readById(r.id)
    verifyEq(r["curVal"], n(123))

    // update force
    g = c.call("commit", Etc.makeMapGrid(["commit":"update", "force":m], ["id":r.id, "mod":DateTime.nowUtc, "forceIt":"forced!"]))
    r = readById(r.id)
    verifyEq(r["forceIt"], "forced!")

    // remove
    g = c.call("commit", Etc.makeMapGrid(["commit":"remove"], ["id":r.id, "mod":r->mod]))
    verifyEq(db.readById(r.id, false), null)
  }

//////////////////////////////////////////////////////////////////////////
// Gets
//////////////////////////////////////////////////////////////////////////

  Void doGets()
  {
    // these ops are ok
    verifyEq(callAsGet("about").first->productName, sys.platform.productName)
    verifyEq(callAsGet("defs").size, c.call("defs").size)
    verifyEq(callAsGet("libs").size, c.call("libs").size)
    verifyEq(callAsGet("filetypes").size, c.call("filetypes").size)
    verifyEq(callAsGet("ops").size, c.call("ops").size)
    verifyEq(callAsGet("read?filter=id").size, c.readAll("id").size)

    // these ops are not
    verifyGetNotAllowed("eval?expr=now()")
    verifyGetNotAllowed("commit?id=@foo")
  }

  Grid callAsGet(Str path)
  {
    str := c.toWebClient(path.toUri).getStr
    return ZincReader(str.in).readGrid
  }

  Void verifyGetNotAllowed(Str path)
  {
    wc := c.toWebClient(path.toUri)
    wc.writeReq
    wc.readRes
    verifyEq(wc.resCode, 405)
    verifyEq(wc.resPhrase.startsWith("GET not allowed for op"), true)
  }

//////////////////////////////////////////////////////////////////////////
// Nav
//////////////////////////////////////////////////////////////////////////

  Void doNav()
  {
    if (sys.platform.rt.isSkySpark) return

    Grid g := c.call("nav", Etc.makeMapGrid(null, Str:Obj[:]))
    verifyEq(g.size, 3)
    verifyEq(g[0].dis, "A")
    verifyEq(g[0].id, g[0]["navId"])

    g = c.call("nav", Etc.makeMapGrid(null, Str:Obj["navId":g[0].id]))
    verifyEq(g.size, 1)
    verifyEq(g[0].dis, "A1")
    verifyEq(g[0].id, g[0]["navId"])

    g = c.call("nav", Etc.makeMapGrid(null, Str:Obj["navId":g[0].id]))
    verifyEq(g.size, 2)
    verifyEq(g[0].dis, "A1X")
    verifyEq(g[0]["navId"], null)
  }

//////////////////////////////////////////////////////////////////////////
// Watches (watchSub, watchPoll, watchUnsub)
//////////////////////////////////////////////////////////////////////////

  private Void doWatches()
  {
    // haystack: watchSub
    w := rt.watch
    verifyEq(w.isWatched(siteA.id), false)
    verifyEq(w.isWatched(eqA1.id), false)
    res := c.call("watchSub", Etc.makeListGrid(["watchDis":"test", "lease":n(17, "min")], "id", null, [siteA.id, eqA1.id]))
    watchId := res.meta->watchId
    verifyEq(res.meta->lease, n(17, "min"))
    verifyEq(res.size, 2)
    verifyDictEq(res[0], siteA)
    verifyDictEq(res[1], eqA1)
    verifyEq(w.list.size, 1)
    verifyEq(w.isWatched(siteA.id), true)
    verifyEq(w.isWatched(eqA1.id), true)
    verifyEq(w.list.first.dis, "test")
    verifyEq(w.list.first.lease, 17min)
    res = c.call("watchPoll", Etc.makeEmptyGrid(["watchId": watchId]))

    // haystack: watchPoll
    eqA1 = commit(eqA1, ["foo":n(123)])
    res = c.call("watchPoll", Etc.makeEmptyGrid(["watchId": watchId]))
    verifyEq(res.size, 1)
    verifyEq(res[0].id, eqA1.id)
    verifyEq(res[0]->foo, n(123))

    // haystack: watchUnsub
    res = c.call("watchUnsub", Etc.makeListGrid(["watchId": watchId], "id", null, [eqA1.id]))
    verifyEq(w.isWatched(siteA.id), true)
    verifyEq(w.isWatched(eqA1.id), false)

    // haystack: watchUnsub
    res = c.call("watchUnsub", Etc.makeEmptyGrid(["watchId": watchId, "close":true]))
    verifyEq(w.list.size, 0)
    verifyEq(w.isWatched(siteA.id), false)
    verifyEq(w.isWatched(eqA1.id), false)
  }

//////////////////////////////////////////////////////////////////////////
// His
//////////////////////////////////////////////////////////////////////////

  Void doHis()
  {
    tz := TimeZone("New_York")
    today := DateTime.now.toTimeZone(tz).midnight
    yesterday := today.date.minus(1day).toDateTime(Time.defVal, tz)
    ptA := addRec(["dis":"His-A", "point":m, "his":m, "kind":"Number", "tz":tz.name])
    ptB := addRec(["dis":"His-B", "point":m, "his":m, "kind":"Number", "tz":tz.name])

    // hisWrite to ptA
    items := HisItem[,]
    items.add(HisItem(yesterday + 1hr, n(1)))
    items.add(HisItem(yesterday + 2hr, n(2)))
    items.add(HisItem(yesterday + 3hr, n(3)))
    items.add(HisItem(today + 1hr, n(10)))
    items.add(HisItem(today + 2hr, n(20)))
    items.add(HisItem(today + 3hr, n(30)))
    req := Etc.makeDictsGrid(["id":ptA.id.noDis], items)
    res := c.call("hisWrite", req)

    // batch hisWrite to ptA, ptB
    gb := GridBuilder()
    ts := Date("2023-05-13").midnight
    gb.addCol("ts").addCol("v0", ["id":ptA.id.noDis]).addCol("v1", ["id":ptB.id.noDis])
    gb.addRow([ts + 0hr, n(100), n(200)])
    gb.addRow([ts + 1hr, null,   n(201)])
    gb.addRow([ts + 2hr, n(102), null])
    gb.addRow([ts + 3hr, n(103), n(203)])
    res = c.call("hisWrite", gb.toGrid)

    // verify ptA got written
    rt.sync
    ptA = rt.db.readById(ptA.id)
    ptB = rt.db.readById(ptB.id)
    verifyEq(ptA["hisSize"], n(9))
    verifyEq(ptB["hisSize"], n(3))

    // hisRead from ptA (yesterday)
    res = c.call("hisRead", Etc.makeMapGrid(null, ["id":ptA.id.noDis, "range":"yesterday"]))
    verifyEq(res.size, 3)
    verifyEq(res.meta->hisStart, yesterday)
    verifyEq(res.meta->hisEnd, today)
    verifyDictEq(res[0], items[0])
    verifyDictEq(res[1], items[1])
    verifyDictEq(res[2], items[2])

    // hisRead from ptA (today)
    res = c.call("hisRead", Etc.makeMapGrid(null, ["id":ptA.id.noDis, "range":"today"]))
    verifyEq(res.size, 3)
    verifyDictEq(res[0], items[3])
    verifyDictEq(res[1], items[4])
    verifyDictEq(res[2], items[5])

    // hisRead from ptA (range)
    res = c.call("hisRead", Etc.makeMapGrid(null, ["id":ptA.id.noDis, "range":items[4].ts.toStr]))
    verifyEq(res.size, 2)
    verifyDictEq(res[0], items[-2])
    verifyDictEq(res[1], items[-1])

    // batch hisRead
    gb = GridBuilder().setMeta(["range":"2023-05-13"]).addCol("id")
    gb.addRow1(ptA.id.noDis)
    gb.addRow1(ptB.id.noDis)
    res = c.call("hisRead", gb.toGrid)
    verifyEq(res.size, 4)
    verifyEq(res.meta->hisStart, ts)
    verifyEq(res.meta->hisEnd, ts.plus(1day))
    verifyDictEq(res[0], ["ts":ts + 0hr, "v0":n(100), "v1":n(200)])
    verifyDictEq(res[1], ["ts":ts + 1hr, "v0":null,   "v1":n(201)])
    verifyDictEq(res[2], ["ts":ts + 2hr, "v0":n(102), "v1":null])
    verifyDictEq(res[3], ["ts":ts + 3hr, "v0":n(103), "v1":n(203)])

    // batch hisRead with explicit tz minus 1hr
    // first row will be clipped
    gb = GridBuilder().setMeta(["range":"2023-05-13", "tz":"Chicago"]).addCol("id")
    tsM1 := ts.date.midnight(TimeZone("Chicago"))
    gb.addRow1(ptA.id.noDis)
    gb.addRow1(ptB.id.noDis)
    res = c.call("hisRead", gb.toGrid)
    verifyEq(res.size, 3)
    verifyEq(res.meta->hisStart.toStr, tsM1.toStr)
    verifyEq(res.meta->hisEnd.toStr, tsM1.plus(1day).toStr)
    verifyEq(res[0]->ts->tz.toStr, "Chicago")
    verifyDictEq(res[0], ["ts":tsM1 + 0hr, "v0":null,   "v1":n(201)])
    verifyDictEq(res[1], ["ts":tsM1 + 1hr, "v0":n(102), "v1":null])
    verifyDictEq(res[2], ["ts":tsM1 + 2hr, "v0":n(103), "v1":n(203)])

    // hisRead with span using Chicago timezone, results in point's tz
    res = c.call("hisRead", Etc.makeMapGrid(null, ["id":ptA.id.noDis, "range":tsM1.toStr + "," +  tsM1.plus(1day).toStr]))
    verifyEq(res.size, 2)
    verifyEq(res.meta->hisStart.toStr, tsM1.toTimeZone(tz).toStr)
    verifyEq(res.meta->hisEnd.toStr, tsM1.plus(1day).toTimeZone(tz).toStr)
    verifyEq(res[0]->ts->tz.toStr, "New_York")
    verifyDictEq(res[0], ["ts":ts + 2hr, "val":n(102)])
    verifyDictEq(res[1], ["ts":ts + 3hr, "val":n(103)])
  }

//////////////////////////////////////////////////////////////////////////
// PointWrite
//////////////////////////////////////////////////////////////////////////

  Void doPointWrite()
  {
    pt := addRec(["dis":"WritePoint", "point":m, "writable":m, "kind":"Number"])

    res := c.call("pointWrite", Etc.makeMapGrid(null, ["id":pt.id, "level":n(16), "val":n(160)]))
    res = c.call("pointWrite", Etc.makeMapGrid(null, ["id":pt.id, "level":n(8), "val":n(80), "duration":n(1, "hr")]))
    res = c.call("pointWrite", Etc.makeMapGrid(null, ["id":pt.id]))

    verifyEq(res.size, 17)
    verifyEq(res[7]->level, n(8))
    verifyEq(res[7]->val, n(80))
    verifyEq(res[7].has("expires"), true)

    verifyEq(res[15]->level, n(16))
    verifyEq(res[15]->val, n(160))
  }

//////////////////////////////////////////////////////////////////////////
// Close
//////////////////////////////////////////////////////////////////////////

  Void doClose()
  {
    c.close

    verifyErrMsg(IOErr#, "Bad HTTP response 403 Invalid or expired authToken") { c.about }
  }

}

