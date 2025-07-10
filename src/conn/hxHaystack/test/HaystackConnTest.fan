//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jan 2012  Brian Frank  Creation
//   30 Dec 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using xeto
using haystack
using axon
using folio
using hx
using hxConn

class HaystackConnTest : HxTest
{
  // server side
  Dict? recA
  Dict? recB
  Dict? pt1
  Dict? pt2
  Dict? pt3
  Dict? ptw
  Dict? hisF
  Dict? hisB

  // client side
  Dict? conn
  Dict? hisSyncF

  @HxRuntimeTest { meta = "steadyState: 10ms" }
  Void test()
  {
    init
    verifyConn
    verifyCall
    verifyReads
    verifyWatches
    verifyPointWrite
    verifyReadHis
    verifySyncHis
    verifyInvokeAction
    verifyHaystackEval
  }

//////////////////////////////////////////////////////////////////////////
// Initialization
//////////////////////////////////////////////////////////////////////////

  Void init()
  {
    // libs
    if (rt.platform.isSkySpark)
      addLib("his")
    else
      addLib("http")
    addLib("task")
    addLib("haystack")

    // user
    addUser("hay", "foo", ["userRole":"admin"])

    // some recs
    recA = addRec(["dis":"Rec A", "i":n(45), "f":n(-33f, "m"), "s":"55\u00B0",
                   "d":Date("2010-05-17"), "t":Time("16:30:00"),
                   "m1":m, "m2":m])
    recB = addRec(["dis":"Rec B", "name":"b", "a":recA.id])

    // site/equip
    s := addRec(["dis":"Site", "site":m])
    e := addRec(["navMacro":"\$siteRef \$navName", "navName":"Equip", "equip":m, "siteRef":s.id])

    // points
    pt1 = addRec(["dis":"Point-1", "name":"pt1", "point":m, "kind":"Bool"])
    pt2 = addRec(["dis":"Point-2", "name":"pt2", "point":m, "kind":"Number", "room":"215"])
    pt3 = addRec(["dis":"Point-3", "point":m, "kind":"Number", "siteRef":s.id, "equipRef":e.id])

    // init curVal
    pt1 = commit(pt1, ["curVal":false], Diff.transient)
    pt2 = commit(pt2, ["curVal":n(75f, "fahrenheit")], Diff.transient)
    pt3 = commit(pt3, ["curVal":n(30, "kW")], Diff.transient)

    // float his
    tz := TimeZone("Chicago")
    h := addRec(["his":m, "point":m, "kind":"Number", "tz":tz.name, "dis":"Num His", "foo":"bar", "unit":"fahrenheit"])
    hisF = readById(h.id)
    items := HisItem[,]
    (1..4).each |mon|
    {
      (1..28).each |day| { items.add(item(dt(2010, mon, day, 12, 0, tz), (mon * day).toFloat)) }
    }
    rt.his.write(h, items)

    // bool his
    tz = TimeZone("Denver")
    h = addRec(["his":m, "kind":"Bool", "tz":tz.name, "dis":"Bool His", "point":m, "val":true])
    hisB = readById(h.id)
    items = HisItem[,]
    (1..4).each |mon|
    {
      (1..28).each |day| { items.add(item(dt(2010, mon, day, 12, 0, tz), (mon * day).isOdd)) }
    }
    rt.his.write(h, items)

    // writable point
    ptw = addRec(["dis":"Point-W", "name":"ptw", "point":m, "writable":m, "kind":"Number", "unit":"%"])
  }

//////////////////////////////////////////////////////////////////////////
// Conn
//////////////////////////////////////////////////////////////////////////

  Void verifyConn()
  {
    // create connector
    uri := rt.http.siteUri + rt.http.apiUri
    conn = addRec(["haystackConn":Marker.val, "uri":uri, "username":"hay", "haystackPollFreq":n(10, "ms")])
    rt.db.passwords.set(conn.id.toStr, "foo")
    rt.sync

    // verify ping (returns rec)
    r := eval("read(haystackConn).haystackPing.futureGet") as Dict
    verifyEq(r.id, conn.id)
    verifyEq(r->productName, rt.platform.productName)
    conn = readById(conn.id)
    verifyEq(conn->connStatus,     "ok")
    verifyEq(conn->productName,    rt.platform.productName)
    verifyEq(conn->productVersion, rt.version.toStr)
    verifyEq(conn->vendorName,     rt.platform.vendorName)
    verifyEq(conn->tz,             TimeZone.cur.name)

    // with conn id
    eval("haystackPing($conn.id.toCode)")
  }

//////////////////////////////////////////////////////////////////////////
// Call
//////////////////////////////////////////////////////////////////////////

  Void verifyCall()
  {
    Grid grid := eval(Str<|read(haystackConn).haystackCall("ops")|>)
    verifyEq(grid.colNames.contains("def"), true)
    r := grid.find |r| { r->def.toStr == "op:about" }
    verifyNotNull(r)
  }

//////////////////////////////////////////////////////////////////////////
// Reads
//////////////////////////////////////////////////////////////////////////

  Void verifyReads()
  {
    // readById
    Dict? x := eval("""read(haystackConn).haystackReadById($recA.id.toCode)""")
    verifyEq(x->dis, "Rec A")
    verifyEq(x->i, n(45f))
    verifyEq(x->f, n(-33.0f, "m"))
    verifyEq(x->s, "55\u00B0")
    verifyEq(x->d, Date("2010-05-17"))
    verifyEq(x->t, Time("16:30:00"))
    verifyEq(x->m1, Marker.val)

    // readById errors
    verifyNull(eval("read(haystackConn).haystackReadById(@badId, false)"))
    verifyEvalErr("read(haystackConn).haystackReadById(@badId)", UnknownRecErr#)
    verifyEvalErr("read(haystackConn).haystackReadById(@badId, true)", UnknownRecErr#)

    // readByIds
    Grid grid := eval("""read(haystackConn).haystackReadByIds([$recA.id.toCode, $recB.id.toCode])""")
    verifyEq(grid.size, 2)
    verifyEq(grid[0]->dis, "Rec A")
    verifyEq(grid[1]->dis, "Rec B")

    // readByIds errors
    grid = eval("read(haystackConn).haystackReadByIds([@badId2, $recA.id.toCode, @badId], false)")
    verifyEq(grid.size, 3)
    verifyEq(grid[0]["id"], null)
    verifyEq(grid[1]["id"], recA.id)
    verifyEq(grid[2]["id"], null)
    verifyEvalErr("read(haystackConn).haystackReadByIds([$recA.id.toCode, @badId])", UnknownRecErr#)
    verifyEvalErr("read(haystackConn).haystackReadByIds([$recA.id.toCode, @badId], true)", UnknownRecErr#)

    // read
    x = eval(Str<|read(haystackConn).haystackRead(dis=="Rec B")|>)
    verifyEq(x->dis, "Rec B")
    verifyEq(x->a, recA.id)

    // read errors
    verifyNull(eval(Str<|read(haystackConn).haystackRead(dis=="bad", false)|>))
    verifyEvalErr(Str<|read(haystackConn).haystackRead(dis=="bad")|>, UnknownRecErr#)
    verifyEvalErr(Str<|read(haystackConn).haystackRead(dis=="bad", true)|>, UnknownRecErr#)

    // readAll
    grid = eval("""read(haystackConn).haystackReadAll(point)""")
    verifyEq(grid.size, 6)
    grid = grid.sortCol("dis")
    verifyEq(grid[0]->dis, "Bool His")
    verifyEq(grid[1]->dis, "Num His")
    verifyEq(grid[2]->dis, "Point-1")
    verifyEq(grid[3]->dis, "Point-2")
    verifyEq(grid[4]->dis, "Point-3")
    verifyEq(grid[5]->dis, "Point-W")
  }

//////////////////////////////////////////////////////////////////////////
// Watches
//////////////////////////////////////////////////////////////////////////

  Void verifyWatches()
  {
     // create proxy rec
     badRef := genRef
     proxy1 := addRec(["dis":"Proxy-1", "haystackConnRef":conn.id,
                       "haystackCur":pt1.id.toStr, "his":Marker.val,
                       "point": Marker.val, "unit":"fahrenheit", "kind":"Bool"])
     proxy2 := addRec(["dis":"Proxy-2", "haystackConnRef":conn.id,
                       "haystackCur":pt2.id.toStr, "his":Marker.val,
                       "point": Marker.val, "unit":"fahrenheit", "kind":"Number"])
     proxy3 := addRec(["dis":"Proxy-3", "haystackConnRef":conn.id,
                       "haystackCur":pt3.id.toStr, "his":Marker.val, "curConvert":"kW=>W",
                       "point": Marker.val, "unit":"W", "kind":"Number"])
     proxy3dup := addRec(["dis":"Proxy-3-Dup", "haystackConnRef":conn.id,
                       "haystackCur":pt3.id.toStr, "his":Marker.val,
                       "point": Marker.val, "unit":"kW", "kind":"Number"])
     proxy3dup2 := addRec(["dis":"Proxy-3-Dup2", "haystackConnRef":conn.id,
                       "haystackCur":pt3.id.toStr, "his":Marker.val,
                       "point": Marker.val, "unit":"kW", "kind":"Number"])
     proxyE1 := addRec(["dis":"Proxy-E1", "haystackConnRef":conn.id,
                       "haystackCur":Ref("bad"), "his":Marker.val,
                       "point": Marker.val, "unit":"fahrenheit", "kind":"Number"])
     proxyE2 := addRec(["dis":"Proxy-E2", "haystackConnRef":conn.id,
                       "haystackCur":badRef.toStr, "his":Marker.val,
                       "point": Marker.val, "unit":"fahrenheit", "kind":"Number"])
     proxyE3 := addRec(["dis":"Proxy-E3", "haystackConnRef":conn.id,
                        "haystackCur":pt2.id.toStr, "his":Marker.val,
                       "point": Marker.val, "unit":"kW", "kind":"Number"])

    // sync
    rt.sync
    eval("readAll(haystackCur).haystackSyncCur")
    syncConn
    verifyCur(proxy1,  false)
    verifyCur(proxy2,  n(75f, "fahrenheit"))
    verifyCur(proxy3,  n(30_000, "W"))
    verifyCur(proxy3dup, n(30, "kW"))
    verifyCur(proxy3dup2, n(30, "kW"))
    verifyCur(proxyE1, null, "fault", "Invalid type for 'haystackCur' [Ref != Str]")
    verifyCur(proxyE2, null ,"fault", "haystack::UnknownRecErr")
    verifyCur(proxyE3, null ,"fault", "sys::Err: point unit != updateCurOk unit: kW != \u00B0F")

    // verify haystackSyncCur setup temp watch on server side
    watches := rt.watch.list
    verifyEq(watches.size, 1)
    verifyEq(watches.first.list.dup.sort, Ref[pt1.id, pt2.id, pt3.id, Ref.fromStr(proxyE2->haystackCur)].sort)

    // make changes
    pt2 = commit(pt2, ["curVal":n(88f, "fahrenheit")], Diff.transient)
    eval("haystackSyncCur($proxy2.id.toCode)")
    syncConn
    verifyCur(proxy2, n(88f, "fahrenheit"), "ok")

    // close all watches to start fresh
    verifyEq(rt.watch.list.size, 2)
    rt.watch.list.each |w| { w.close }
    verifyEq(rt.watch.list.size, 0)

    // clear proxies
    resetCur(proxy1)
    resetCur(proxy2)
    resetCur(proxy3)
    resetCur(proxy3dup)
    resetCur(proxy3dup2)
    resetCur(proxyE1)
    resetCur(proxyE2)

    // now setup watch on the proxies
    clientWatch := rt.watch.open("test")
    clientWatch.addAll([proxy1.id, proxyE1.id, proxyE2.id])
    Actor.sleep(100ms)
    syncConn

    // verify that watches got setup on server side
    watches = rt.watch.list
    verifyEq(watches.size, 2)
    serverWatch := watches.find |x| { x !== clientWatch }
    verifyEq(serverWatch.list.dup.sort, [pt1.id, badRef].sort)

    // now add new points to watch
    clientWatch.addAll([proxy2.id, proxy3.id, proxy3dup.id])
    Actor.sleep(100ms)
    syncConn

    // verify server watch
    verifyEq(serverWatch.list.dup.sort, [badRef, pt1.id, pt2.id, pt3.id].sort)

    // make some server side changes
    pt1 = commit(pt1, ["curVal":true], Diff.transient)
    pt2 = commit(pt2, ["curVal":n(99f, "fahrenheit")], Diff.transient)
    pt3 = commit(pt3, ["curVal":n(40f, "kW")], Diff.transient)

    // test that proxies updated
    Actor.sleep(100ms)
    syncConn
    verifyCur(proxy1, true)
    verifyCur(proxy2, n(99f, "fahrenheit"))
    verifyCur(proxy3, n(40_000, "W"))
    verifyCur(proxy3dup, n(40, "kW"))
    verifyCur(proxyE1, null, "fault", "Invalid type for 'haystackCur' [Ref != Str]")
    verifyCur(proxyE2, null ,"fault", "haystack::UnknownRecErr")

    // now add triple dup
    clientWatch.addAll([proxy3dup2.id])
    Actor.sleep(100ms)
    syncConn

    // more server side changes
    pt1 = commit(pt1, ["curVal":false], Diff.transient)
    pt2 = commit(pt2, ["curVal":n(1972f, "fahrenheit")], Diff.transient)
    pt3 = commit(pt3, ["curVal":n(50, "kW")], Diff.transient)

    // test that proxies updated
    Actor.sleep(150ms)
    syncConn
    verifyCur(proxy1, false)
    verifyCur(proxy2, n(1972, "fahrenheit"))
    verifyCur(proxy3, n(50_000, "W"))
    verifyCur(proxy3dup, n(50, "kW"))
    verifyCur(proxy3dup2, n(50, "kW"))

    // put server side into error conditions
    pt1 = commit(pt1, ["curStatus":"ok", "curVal":true], Diff.transient)
    pt2 = commit(pt2, ["curStatus":"down"], Diff.transient)
    pt3 = commit(pt3, ["curStatus":"remoteFault"], Diff.transient)

    // verify remoteStatus errors
    Actor.sleep(500ms)
    verifyCur(proxy1, true, "ok")
    verifyCur(proxy2, null, "remoteDown", "Remote status err: down")
    verifyCur(proxy3, null, "remoteFault", "Remote status err: remoteFault")
    verifyCur(proxy3dup, null, "remoteFault", "Remote status err: remoteFault")

    // remove proxy2 from watch
    clientWatch.remove(proxy2.id)
    Actor.sleep(100ms)
    verifyEq(serverWatch.list.dup.sort, [badRef, pt1.id, pt3.id].sort)

    // close client side watch
    clientWatch.close
    Actor.sleep(100ms)
    syncConn

    // verify server side watch is closed too
    verifyEq(serverWatch.isClosed, true)
  }

  Void verifyCur(Dict r, Obj? val, Str status := "ok", Str? err := null)
  {
    r = readById(r.id)
    // echo("--> verifyCur " + r.dis + " " + r["curVal"] + " @ " + r["curStatus"] + " err=" +  r["curErr"])
    // echo(rt.conn.point(r.id).details)
    verifyEq(r["curVal"], val)
    verifyEq(r["curStatus"], status)
    verifyEq(r["curErr"], err)
  }

  Void resetCur(Dict r)
  {
    // not sure we need nor want this
    //commit(r, ["curVal":Remove.val, "curStatus":Remove.val, "curErr":Remove.val], Diff.forceTransient)
  }

//////////////////////////////////////////////////////////////////////////
// Point Writes
//////////////////////////////////////////////////////////////////////////

  Void verifyPointWrite()
  {
     // bad proxies
     bad1 := addRec(["dis":"ProxyW", "haystackConnRef":conn.id,
                     "haystackCur":ptw.id.toStr, "haystackWrite":ptw.id, "writable":Marker.val,
                     "point": Marker.val, "unit":"%", "kind":"Number"])
     bad2 := addRec(["dis":"ProxyW", "haystackConnRef":conn.id,
                     "haystackCur":ptw.id.toStr, "haystackWrite":ptw.id.toStr, "writable":Marker.val,
                     "point": Marker.val, "unit":"%", "kind":"Number"])
     bad3 := addRec(["dis":"ProxyW", "haystackConnRef":conn.id,
                     "haystackCur":ptw.id.toStr, "haystackWrite":ptw.id.toStr, "haystackWriteLevel":n(18), "writable":Marker.val,
                     "point": Marker.val, "unit":"%", "kind":"Number"])
     bad4 := addRec(["dis":"ProxyW", "haystackConnRef":conn.id,
                     "haystackCur":ptw.id.toStr, "haystackWrite":"badone", "haystackWriteLevel": n(15), "writable":Marker.val,
                     "point": Marker.val, "unit":"%", "kind":"Number"])

     // good proxy
     proxy := addRec(["dis":"ProxyW", "haystackConnRef":conn.id,
                       "haystackCur":ptw.id.toStr, "haystackWrite":ptw.id.toStr, "haystackWriteLevel":n(15),
                       "writable":Marker.val, "point": Marker.val, "unit":"%", "kind":"Number"])

     // make sure we are at steady state
     while (!rt.isSteadyState) Actor.sleep(10ms)

     // get stuff setup
     eval("pointOverride($bad1.id.toCode,  1)")
     eval("pointOverride($bad2.id.toCode,  2)")
     eval("pointOverride($bad3.id.toCode,  3)")
     eval("pointOverride($bad4.id.toCode,  3)")
     eval("pointOverride($proxy.id.toCode, 99)")
     syncConn

     // bad1: wrong type for haystackWrite
     bad1 = readById(bad1.id)
     verifyEq(bad1["writeStatus"], "fault")
     verifyEq(bad1["writeErr"], "Invalid type for 'haystackWrite' [Ref != Str]")

     // bad2: missing haystackWriteLevel
     bad2 = readById(bad2.id)
     verifyEq(bad2["writeStatus"], "fault")
     verifyEq(bad2["writeErr"], "missing haystackWriteLevel")

     // bad3: haystackWriteLevel invalid
     bad3 = readById(bad3.id)
     verifyEq(bad3["writeStatus"], "fault")
     verifyEq(bad3["writeErr"], "haystackWriteLevel is not 1-17: 18")

     // bad4: haystackWrite bad address
     bad4 = readById(bad4.id)
     verifyEq(bad4["writeStatus"], "fault")
     verifyEq(bad4["writeErr"], "haystack::CallErr: haystack::UnknownRecErr: ${bad4->haystackWrite}")

     // proxy
     proxy = readById(proxy.id)
     verifyEq(proxy["writeStatus"], "ok")
     verifyEq(proxy["writeErr"], null)
     verifyEq(proxy["writeVal"], n(99))
     verifyEq(proxy["writeLevel"], n(8))

     // server point
     ptw = readById(ptw.id)
     verifyEq(ptw["writeStatus"], null)
     verifyEq(ptw["writeLevel"], n(15))
     verifyEq(ptw["writeVal"], n(99))
     array := evalToGrid("pointWriteArray($ptw.id.toCode)")
     verifyEq(array[15-1]["level"], n(15)); verifyEq(array[15-1]["val"], n(99))
     verifyEq(array[16-1]["level"], n(16)); verifyEq(array[16-1]["val"], null)
     verifyEq(array[15-1]["who"], "Haystack.pointWrite | test :: ProxyW")

     // change haystackWriteLevel and verify that old levels gets nulled out
     proxy = commit(proxy, ["haystackWriteLevel":n(16)])
     eval("pointOverride($proxy.id.toCode, 321)")
     syncConn

     // proxy
     proxy = readById(proxy.id)
     verifyEq(proxy["writeStatus"], "ok")
     verifyEq(proxy["writeErr"], null)
     verifyEq(proxy["writeVal"], n(321))
     verifyEq(proxy["writeLevel"], n(8))

     // server point
     ptw = readById(ptw.id)
     verifyEq(ptw["writeStatus"], null)
     verifyEq(ptw["writeLevel"], n(16))
     verifyEq(ptw["writeVal"], n(321))
     array = evalToGrid("pointWriteArray($ptw.id.toCode)")
     verifyEq(array[15-1]["level"], n(15)); verifyEq(array[15-1]["val"], null)
     verifyEq(array[16-1]["level"], n(16)); verifyEq(array[16-1]["val"], n(321))
  }

//////////////////////////////////////////////////////////////////////////
// His
//////////////////////////////////////////////////////////////////////////

  Void verifyReadHis()
  {
    doVerifyReadHis(hisF, "2010-03-01")
    doVerifyReadHis(hisF, "2010-02-23..2010-03-04")
  }

  Void doVerifyReadHis(Dict rec, Str range)
  {
    // run query over haystack
    Grid actual := eval("read(haystackConn).haystackHisRead($rec.id.toCode, $range)")

    // run query locally
    Grid expected := readHisToGrid(rec, range)

    verifyEq(actual.size, expected.size)
    verifyEq(actual.meta["hisStart"], expected.meta["hisStart"])
    verifyEq(actual.meta["hisEnd"], expected.meta["hisEnd"])
    expected.each |e, i|
    {
      a := actual[i]
      verifyEq(e->ts, a->ts)
      verifyEq(e->val, a->val)
    }
  }

  private Grid readHisToGrid(Dict rec, Str range)
  {
    span := rangeToSpan(rec, range)
    items := HisItem[,]
    rt.his.read(rec, span, null) |item|
    {
      if (span.contains(item.ts)) items.add(item)
    }
    grid := Etc.makeDictsGrid(["hisStart":span.start, "hisEnd":span.end], items)
    return grid
  }

  private Span rangeToSpan(Dict rec, Str range)
  {
    tz := TimeZone(rec->tz.toStr)
    dots := range.index("..")
    if (dots == null)
      return DateSpan(Date(range)).toSpan(tz)
    else
      return DateSpan(Date(range[0..<dots]), Date(range[dots+2..-1])).toSpan(tz)
  }

  Void verifySyncHis()
  {
    // create proxy rec
    hisSyncF = addRec(["dis":"Test Proxy", "haystackConnRef":conn.id,
                       "haystackHis":hisF.id.toStr, "his":Marker.val,
                       "tz":"Chicago", "point": Marker.val,
                       "unit":"fahrenheit", "kind":"Number"])

    // sync
    eval("readById($hisSyncF.id.toCode).haystackSyncHis(2010)")
    syncConn

    // verify history was synced
    hisSyncF = readById(hisSyncF.id)
    hisF = readById(hisF.id)
    verifyEq(hisSyncF->hisSize,  hisF->hisSize)
    verifyEq(hisSyncF->hisStart, hisF->hisStart)
    verifyEq(hisSyncF->hisEnd,   hisF->hisEnd)
    verifyEq(hisSyncF["hisStatus"], "ok")
    verifyEq(hisSyncF["hisErr"], null)
    a := HisItem[,]; rt.his.read(hisF, null, null) |item| { a.add(item) }
    b := HisItem[,]; rt.his.read(hisSyncF, null, null) |item| { b.add(item) }
    verifyEq(a, b)
    verifyEq(a.first.val->unit, Unit("fahrenheit"))
    verifyEq(b.first.val->unit, Unit("fahrenheit"))


    // add new items to hisF
    tz := TimeZone("Chicago")
    rt.his.write(hisF,
      [
        item(dt(2010, 5, 1, 1, 0, tz), 110f),
        item(dt(2010, 5, 1, 2, 0, tz), 120f),
        item(dt(2010, 5, 1, 3, 0, tz), 130f),
        item(dt(2010, 5, 1, 4, 0, tz), 140f),
        item(dt(2010, 5, 1, 5, 0, tz), 150f),
        item(dt(2010, 5, 2, 1, 0, tz), 210f),
        item(dt(2010, 5, 2, 2, 0, tz), 220f),
        item(dt(2010, 5, 2, 3, 0, tz), 230f),
      ]).get

    // sync with span
    eval("readById($hisSyncF.id.toCode).haystackSyncHis(2010-05-01)")
    syncConn

    // verify history was synced
    hisSyncF = readById(hisSyncF.id)
    hisF = readById(hisF.id)
    verifyEq(hisSyncF->hisSize,  n(-3) + hisF->hisSize) // don't have May 2nd yet
    verifyEq(hisSyncF->hisStart, hisF->hisStart)
    verifyEq(hisSyncF->hisEnd,   dt(2010, 5, 1, 5, 0, tz))
    a.clear; rt.his.read(hisF, null, null) |item| { a.add(item) }
    b.clear; rt.his.read(hisSyncF, null, null) |item| { b.add(item) }
    verifyEq(a.size - 3, b.size)
    verifyEq(a[0..-4], b)

    // sync with no span
    eval("readById($hisSyncF.id.toCode).haystackSyncHis")
    syncConn

    // verify completly in sync
    hisSyncF = readById(hisSyncF.id)
    verifyEq(hisSyncF->hisSize,  hisF->hisSize)
    verifyEq(hisSyncF->hisStart, hisF->hisStart)
    verifyEq(hisSyncF->hisEnd,   hisF->hisEnd)
    a.clear; rt.his.read(hisF, null, null) |item| { a.add(item) }
    b.clear; rt.his.read(hisSyncF, null, null) |item| { b.add(item) }
    verifyEq(a.size, b.size)
    verifyEq(a, b)
  }

  Void syncConn()
  {
    lib := (HaystackLib)rt.libsOld.get("haystack")
    rt.sync
    lib.conn(conn.id).sync
  }

//////////////////////////////////////////////////////////////////////////
// Invoke Action
//////////////////////////////////////////////////////////////////////////

  Void verifyInvokeAction()
  {
    // we don't have invokeAction in Haxall right now
    if (!rt.platform.isSkySpark) return

    // create rec with action
    r := addRec(["dis":"Action", "count":n(1), "msg1": "", "msg2":"", "actions":
      Str<|ver: "2.0"
           dis,expr
           "test1","commit(diff(\$self, {count: \$self->count+1}))"
           "test2","commit(diff(\$self, {msg1: \$str, msg2:\"\"+\$number}))"|>])

    // test setup
    eval("""invoke($r.id.toCode, "test1")""")
    eval("""invoke($r.id.toCode, "test2", {str:"init", number:123})""")
    r = readById(r.id)
    verifyEq(r->count, n(2))
    verifyEq(r->msg1, "init")
    verifyEq(r->msg2, "123")

    // make remote calls
    eval("""read(haystackConn).haystackInvokeAction($r.id.toCode, "test1")""")
    eval("""read(haystackConn).haystackInvokeAction($r.id.toCode, "test2", {str:"network",number:987})""")
    r = readById(r.id)
    verifyEq(r->count, n(3))
    verifyEq(r->msg1, "network")
    verifyEq(r->msg2, "987")
  }

//////////////////////////////////////////////////////////////////////////
// Eval
//////////////////////////////////////////////////////////////////////////

  Void verifyHaystackEval()
  {
    // create rec with action
    Grid g := eval("""read(haystackConn).haystackEval(3 + 5)""")
    verifyEq(g.size, 1)
    verifyEq(g.first->val, n(8))

    g = eval("""read(haystackConn).haystackEval(readAll(haystackConn))""")
    verifyEq(g.size, 1)
    verifyDictEq(g.first, conn)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  static HisItem item(DateTime ts, Obj? val)
  {
    if (val is Num) val = Number.makeNum(val)
    return HisItem(ts, val)
  }

  static DateTime dt(Int y, Int m, Int d, Int h, Int min, TimeZone tz := TimeZone.utc)
  {
    DateTime(y, Month.vals[m-1], d, h, min, 0, 0, tz)
  }

  Grid evalToGrid(Str axon) { eval(axon) }

  Void verifyEvalErr(Str axon, Type? errType)
  {
    expr := Parser(Loc.eval, axon.in).parse
    scope := makeContext
    EvalErr? err := null
    try { expr.eval(scope) } catch (EvalErr e) { err = e }
    if (err == null) fail("EvalErr not thrown: $axon")
    if (errType == null)
    {
      verifyNull(err.cause)
    }
    else
    {
      if (err.cause == null) fail("EvalErr.cause is null: $axon")
      ((Test)this).verifyErr(errType) { throw err.cause }
    }
  }

}

