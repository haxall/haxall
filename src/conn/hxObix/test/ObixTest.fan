//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Jun 2009  Brian Frank  Creation
//    3 Feb 2022  Brian Frank  Redesign for Haxall
//

using concurrent
using web
using haystack
using xeto
using obix
using folio
using hx

**
** ObixTest
**
class ObixTest : HxTest
{
  ObixExt? lib
  ObixClient? client
  Uri? lobbyUri

  // server side recs
  Dict? recA
  Dict? recB
  Dict? pt1
  Dict? pt2
  Dict? pt3
  Dict? hisF
  Dict? hisB

  // client side recs
  Dict? conn
  Dict? hisSyncF

  @HxTestProj
  Void test()
  {
    buildProj
    verifyLobby
    verifyReads
    verifyBatch
    verifyPoints
    verifyHis
    verifyHisQueries
    verifyConn
    verifyReadHis
    verifyHisSync
    verifyServerWatches
    verifyClientWatches
    verifyWritables
  }

  Void buildProj()
  {
    if (proj.platform.isSkySpark)
      addLib("his")
    else
      addLib("http")
    addLib("task")
    lib = addLib("obix")

    // some recs
    m := Marker.val
    recA = addRec(["dis":"Rec A", "i":n(45), "f":n(-33f), "s":"55\u00B0",
                   "d":Date("2010-05-17"), "t":Time("16:30:00"),
                   "m1":m, "m2":m, "geoCoord": Coord(10f, -20f)])
    recB = addRec(["dis":"Rec B", "id":Ref("b"), "a":recA.id])

    // points
    pt1 = addRec(["dis":"Point #1", "id":Ref("pt1"), "point":m, "kind":"Bool"])
    pt2 = addRec(["dis":"Point #2", "id":Ref("pt2"), "point":m, "kind":"Number", "room":"215"])
    pt3 = addRec(["dis":"Point #3", "id":Ref("pt3"), "point":m, "kind":"Number", "writable":m])

    // point transients
    pt1 = commit(pt1, ["curVal":false], Diff.transient)
    pt2 = commit(pt2, ["curVal":n(75f, "fahrenheit")], Diff.transient)

    // history
    tz := TimeZone("Chicago")
    h := addRec(["point":m, "his":m, "kind":"Number", "tz":tz.name, "dis":"Float His", "foo":"bar", "unit":"fahrenheit"])
    hisF = readById(h.id)
    items := HisItem[,]
    (1..4).each |mon|
    {
      (1..28).each |day| { items.add(item(dt(2010, mon, day, 12, 0, tz), (mon * day).toFloat)) }
    }
    hisExt.write(h, items)

    // history
    tz = TimeZone("Denver")
    h = addRec(["his":m, "kind":"Bool", "tz":tz.name, "dis":"Bool His", "point":m])
    hisB = readById(h.id)
    items = HisItem[,]
    (1..4).each |mon|
    {
      (1..28).each |day| { items.add(item(dt(2010, mon, day, 12, 0, tz), (mon * day).isOdd)) }
    }
    hisExt.write(h, items)
  }

  Void verifyLobby()
  {
    lib := (ObixExt)proj.ext("hx.obix")
    projApiUri := proj.sys.http.siteUri + proj.sys.http.apiUri
    lobbyUri = projApiUri + lib.web.uri

    // first use a haystack client to authenticate
    addUser("alice", "secret")
    authClient := Client.open(projApiUri, "alice", "secret")

    // init client
    client = ObixClient(lobbyUri, authClient.auth->headers)

    // verify lobby
    lobby := client.readLobby
    // lobby.writeXml(Env.cur.out)
    verifyEq(lobby.href, lobbyUri)
    verifyEq(lobby.contract.toStr, "obix:Lobby")
    verifyEq(client.aboutUri, `about/`)

    // verify about
    about := client.readAbout
    // about.writeXml(Env.cur.out)
    verifyEq(about.href, lobbyUri + `about/`)
    verifyEq(about.contract.toStr, "obix:About")
    verifyEq(about.get("obixVersion").val, "1.1")
    verifyEq(about.get("serverName").val,  proj.name)
    verifyEq(about.get("vendorName").val,  proj.platform.vendorName)
    verifyEq(about.get("productName").val, proj.platform.productName)
    verifyEq(about.get("tz").val,          TimeZone.cur.fullName)
  }

  Void verifyReads()
  {
    // verify recA
    x := client.read(`rec/${recA.id}`)
    verifyEq(x.href, lobbyUri + `rec/${recA.id}/`)
    verifyEq(x.contract.toStr, "tag:m1 tag:m2")
    verifyEq(x.displayName, "Rec A")
    verifyEq(x.elemName, "obj")
    verifyEq(x.get("dis").val, "Rec A")
    verifyEq(x.get("i").href, `i`)
    verifyEq(x.get("i").val, 45f)
    verifyEq(x.get("f").val, -33.0f)
    verifyEq(x.get("s").val, "55\u00B0")
    verifyEq(x.get("d").val, Date("2010-05-17"))
    verifyEq(x.get("t").val, Time("16:30:00"))
    verifyEq(x.get("m1", false), null)
    verifyEq(x.get("geoCoord").val, "C(10.0,-20.0)")

    // verify recA/i
    x = client.read(`rec/${recA.id}/i`)
    verifyEq(x.href, lobbyUri + `rec/${recA.id}/i/`)
    verifyEq(x.contract.toStr, "")
    verifyEq(x.elemName, "real")
    verifyEq(x.val, 45f)
    verifyEq(x.size, 0)

    // verify recB w/ name
    x = client.read(`rec/b/`)
    verifyEq(x.href, lobbyUri + `rec/b/`)
    verifyEq(x.contract.toStr, "")
    verifyEq(x.displayName, "Rec B")
    verifyEq(x.get("a").elemName, "ref")
    verifyEq(x.get("a").href, href(`rec/${recA.id}/`))
  }

  Void verifyBatch()
  {
    res := client.batchRead([`rec/${recA.id}/i`, `rec/b/`])
    verifyEq(res.size, 2)
    verifyEq(res[0].val, 45f)
    verifyEq(res[0].href, href(`rec/${recA.id}/i`))
    verifyEq(res[1].displayName, "Rec B")
    verifyEq(res[1].href, href(`rec/b/`))
  }

  Void verifyPoints()
  {
    // pt1
    x := client.read(`rec/pt1`)
    verifyEq(x.href, lobbyUri + `rec/pt1/`)
    verifyEq(x.contract.toStr, "obix:Point tag:point")
    verifyEq(x.elemName, "bool")
    verifyEq(x.displayName, "Point #1")
    verifyEq(x.val, false)

    // pt2
    x = client.read(`rec/pt2/`)
    verifyEq(x.href, lobbyUri + `rec/pt2/`)
    verifyEq(x.contract.toStr, "obix:Point tag:point")
    verifyEq(x.elemName, "real")
    verifyEq(x.displayName, "Point #2")
    verifyEq(x.val, 75f)
    verifyEq(x.unit, Unit.fromStr("fahrenheit"))
    verifyEq(x.get("room").val, "215")
  }

  Void verifyHis()
  {
    // re-read histories, his work should be done by now
    hisF = readById(hisF.id)
    hisB = readById(hisB.id)

    // verify hisF
    x := client.read(`rec/${hisF.id}`)
    verifyEq(x.href, lobbyUri + `rec/${hisF.id}/`)
    verifyEq(x.contract.toStr, "obix:Point obix:History tag:point tag:his")
    verifyEq(x.elemName, "obj")
    verifyEq(x.displayName, "Float His")
    verifyEq(x.get("count").val, hisF->hisSize->toInt)
    verifyEq(x.get("start").val, hisF->hisStart)
    verifyEq(x.get("start").tz,  TimeZone("Chicago"))
    verifyEq(x.get("end").val,   hisF->hisEnd)
    verifyEq(x.get("end").tz,    TimeZone("Chicago"))
    verifyEq(x.get("tz").val,    "America/Chicago")

    // verify hisF/query
    q := x.get("query")
    verifyEq(q.href, `query`)
    testQuery := |->|
    {
      verifyEq(q.elemName, "op")
      verifyEq(q.in.toStr, "obix:HistoryFilter")
      verifyEq(q.out.toStr, "obix:HistoryQueryOut")
    }
    q = client.read(`rec/${hisF.id}/query`)
    verifyEq(q.href, lobbyUri + `rec/${hisF.id}/query/`)
    testQuery()

    // verify hisB (both history and point)
    x = client.read(`rec/${hisB.id}`)
    verifyEq(x.href, lobbyUri + `rec/${hisB.id}/`)
    verifyEq(x.contract.uris.dup.sort,
      [`obix:Point`, `obix:History`, `tag:his`, `tag:point`].sort)
    verifyEq(x.displayName, "Bool His")
    verifyEq(x.get("count").val, hisB->hisSize->toInt)
    verifyEq(x.get("start").val, hisB->hisStart)
    verifyEq(x.get("start").tz,  TimeZone("Denver"))
    verifyEq(x.get("end").val,   hisB->hisEnd)
    verifyEq(x.get("end").tz,    TimeZone("Denver"))
    verifyEq(x.get("tz").val,    "America/Denver")
  }

  Void verifyHisQueries()
  {
    tz := TimeZone.fromStr(hisF->tz)
    verifyHisQuery(hisF, null, null)
    // partial spans no longer supported
    // verifyHisQuery(hisF, Date("2010-03-01").midnight(tz), null)
    // verifyHisQuery(hisF, null, Date("2010-02-01").midnight(tz))
    verifyHisQuery(hisF, Date("2010-02-01").midnight(tz), Date("2010-03-01").midnight(tz))
    verifyHisQuery(hisF, null, null, 5)
  }

  Void verifyHisQuery(Dict rec, DateTime? s, DateTime? e, Int? limit := null)
  {
    // echo("====== verifyHisQuery ${rec->dis} $s $e")
    tz := TimeZone.fromStr(rec->tz)

    // build up obix:HistoryFilter
    arg := ObixObj
    {
      ObixObj { name = "limit"; val = limit },
      ObixObj { name = "start"; val = s },
      ObixObj { name = "end";   val = e },
    }
    r := client.invoke(`rec/${rec.id}/query`, arg)
    // dump("result", r)

    // verify basics
    verifyEq(r.contract.toStr, "obix:HistoryQueryOut")
    verifyEq(r.get("count").val, r.get("data").size)
    if (limit != null) verify(r.get("count").val <= limit)
    verifyEq(r.get("start").val, s)
    verifyEq(r.get("end").val,   e)
    verifyEq(r.get("proto").get("timestamp").tz, tz)
    if (rec.has("unit"))
    {
      verifyEq(r.get("proto").get("value").elemName, "real")
      verifyEq(r.get("proto").get("value").unit, Unit.fromStr(rec->unit))
    }

    // read items
    items := HisItem[,]
    hisExt.read(rec, s == null ? null : Span(s, e), null) |item| { items.add(item) }
    if (limit != null) items = items[0..<limit]

    // verify items
    data := r.get("data")
    verifyEq(items.size, data.size)
    i := 0
    data.each |x|
    {
      item := items[i++]
      verifyEq(x.get("timestamp").val, item.ts)
      verifyEq(x.get("value").val,     item.val->toFloat)
    }
  }

  Void verifyConn()
  {
    // create connector
    conn = addRec(["obixConn":Marker.val, "obixLobby":lobbyUri, "username":"alice", "obixPollFreq":n(10, "ms")])
    proj.db.passwords.set(conn.id.toStr, "secret")

    // verify ping
    r := eval("read(obixConn).obixPing.futureGet")
    sync
    conn = read("obixConn")
    // echo(lib.conn(conn.id).details)
    verifyEq(conn->connStatus, "ok")
    verifyEq(conn->connState,  "open")
    verifyEq(conn->vendorName,  sys.platform.vendorName)
    verifyEq(conn->productName, sys.platform.productName)
    verifyEq(conn->tz,          TimeZone.cur.name)

    // with conn id
    eval("obixPing(${conn.id.toCode})")
  }

  Void verifyReadHis()
  {
    Grid grid := eval("obixReadHis(${conn.id.toCode}, `rec/${hisF.id}`, 2010-04-01)")
    verifyEq(grid.size, 4)
    verifyEq(grid[0]->ts->date, Date(2010, Month.mar, 28))
    verifyEq(grid[1]->ts->date, Date(2010, Month.apr, 1))
    verifyEq(grid[2]->ts->date, Date(2010, Month.apr, 2))
  }

  Void verifyHisSync()
  {
    // create obixHis rec
    hisSyncF = addRec(["dis":"Test Proxy", "obixConnRef":conn.id, "obixHis":`rec/${hisF.id}`, "his":m,
                       "tz":"Chicago", "point":m, "unit":"fahrenheit", "kind":"Number"])
    sync

    // sync
    r := eval("readById($hisSyncF.id.toCode).obixSyncHis(2010)")
    sync

    // verify history was synced
    hisSyncF = readById(hisSyncF.id)
    hisF = readById(hisF.id)
    verifyEq(hisSyncF->hisSize,  hisF->hisSize)
    verifyEq(hisSyncF->hisStart, hisF->hisStart)
    verifyEq(hisSyncF->hisEnd,   hisF->hisEnd)
    verifyEq(hisSyncF->hisStatus, "ok")
    a := HisItem[,]; hisExt.read(hisF, null, null) |item| { a.add(item) }
    b := HisItem[,]; hisExt.read(hisSyncF, null, null) |item| { b.add(item) }
    verifyEq(a, b)
    verifyEq(a.first.val->unit, Unit("fahrenheit"))
    verifyEq(b.first.val->unit, Unit("fahrenheit"))

    // add new items to hisF
    tz := TimeZone("Chicago")
    hisExt.write(hisF,
      [
        item(dt(2010, 5, 1, 1, 0, tz), 110f),
        item(dt(2010, 5, 1, 2, 0, tz), 120f),
        item(dt(2010, 5, 1, 3, 0, tz), 130f),
        item(dt(2010, 5, 1, 4, 0, tz), 140f),
        item(dt(2010, 5, 1, 5, 0, tz), 150f),
        item(dt(2010, 5, 2, 1, 0, tz), 210f),
        item(dt(2010, 5, 2, 2, 0, tz), 220f),
        item(dt(2010, 5, 2, 3, 0, tz), 230f),
      ])

    // sync with range
    eval("readById($hisSyncF.id.toCode).obixSyncHis(2010-05-01)")
    sync

    // verify history was synced
    hisSyncF = readById(hisSyncF.id)
    hisF = readById(hisF.id)
    verifyEq(hisSyncF->hisStart, hisF->hisStart)
    verifyEq(hisSyncF->hisEnd,   dt(2010, 5, 1, 5, 0, tz))
    verifyEq(hisSyncF->hisSize,  n(-3) + hisF->hisSize) // don't have May 2nd yet
    a.clear; hisExt.read(hisF, null, null) |item| { a.add(item) }
    b.clear; hisExt.read(hisSyncF, null, null) |item| { b.add(item) }
    verifyEq(a.size - 3, b.size)
    verifyEq(a[0..-4], b)

    // sync with no range
    eval("readById($hisSyncF.id.toCode).obixSyncHis")
    Actor.sleep(100ms)

    // verify completly in sync
    hisSyncF = readById(hisSyncF.id)
    verifyEq(hisSyncF->hisSize,  hisF->hisSize)
    verifyEq(hisSyncF->hisStart, hisF->hisStart)
    verifyEq(hisSyncF->hisEnd,   hisF->hisEnd)
    a.clear; hisExt.read(hisF, null, null) |item| { a.add(item) }
    b.clear; hisExt.read(hisSyncF, null, null) |item| { b.add(item) }
    verifyEq(a, b)
  }

  Void verifyServerWatches()
  {
    // make a watch
    w := client.invoke(`watchService/make`, ObixObj())
    verifyWatch(w)

    // now read its href
    w2 := client.read(w.href)
    verifyEq(w.href, w2.href)
    verifyWatch(w2)

    // write lease, read lease, re-read entire watch
    wlease := client.write(ObixObj { it.href=w.get("lease").normalizedHref; val = 47sec })
    verifyEq(wlease.val, 47sec)
    wlease = client.read(w.get("lease").normalizedHref)
    verifyEq(wlease.val, 47sec)
    verifyEq(wlease.href, w.get("lease").normalizedHref)
    w = client.read(w.href)
    verifyWatch(w)

    // add some URIs
    list := ObixObj { elemName = "list"; name = "hrefs" }
    list.add(ObixObj { val = this.href(`rec/${recA.id}/`) })
    list.add(ObixObj { val = this.href(`rec/${recB.id}/`) })
    list.add(ObixObj { val = this.href(`rec/${pt1.id}`) }) // error
    list.add(ObixObj { val = `foobar` })         // error
    res := client.invoke(w.get("add").normalizedHref, ObixObj { add(list) })
    vals := res.get("values").list
    verifyEq(vals.size, 4)
    verifyEq(vals[0].href, href(`rec/${recA.id}/`))
    verifyEq(vals[0].normalizedHref, lobbyUri +`rec/${recA.id}/`)
    verifyEq(vals[0].displayName, "Rec A")
    verifyEq(vals[0].get("f").val, -33f)
    verifyEq(vals[1].href, href(`rec/${recB.id}/`))
    verifyEq(vals[1].displayName, "Rec B")
    verifyEq(vals[1].get("a").href, href(`rec/${recA.id}/`))
    verifyEq(vals[1].get("a").display, "Rec A")
    verifyWatchUnresolvedErr(vals[2], href(`rec/${pt1.id}`))
    verifyWatchUnresolvedErr(vals[3], `foobar`)
    verifyWatchIds(w, [recA, recB])

    // add two more URIs
    list = ObixObj { elemName = "list"; name = "hrefs" }
    list.add(ObixObj { val = this.href(`rec/${pt2.id}/`) })
    list.add(ObixObj { val = this.href(`rec/badone/`) })
    res = client.invoke(w.get("add").normalizedHref, ObixObj { add(list) })
    vals = res.get("values").list
    verifyEq(vals.size, 2)
    verifyEq(vals[0].href, href(`rec/${pt2.id}/`))
    verifyEq(vals[0].displayName, "Point #2")
    verifyEq(vals[0].val, 75f)
    verifyEq(vals[0].get("curVal").val, 75f)
    verifyWatchUnresolvedErr(vals[1], href(`rec/badone/`))
    verifyWatchIds(w, [recA, recB, pt2])

    // poll for changes - first there should be 4, then none
    res = client.invoke(w.get("pollChanges").normalizedHref, ObixObj {})
    vals = res.get("values").list
    verifyEq(vals.size, 3)
    res = client.invoke(w.get("pollChanges").normalizedHref, ObixObj {})
    vals = res.get("values").list
    verifyEq(vals.size, 0)

    // make some changes
    pt2 = commit(pt2, ["curVal":n(90f), "curStatus":"fault"], Diff.transient)
    res = client.invoke(w.get("pollChanges").normalizedHref, ObixObj {})
    vals = res.get("values").list
    verifyEq(vals.size, 1)
    verifyEq(vals[0].href, href(`rec/${pt2.id}/`))
    verifyEq(vals[0].normalizedHref, lobbyUri + `rec/${pt2.id}/`)
    verifyEq(vals[0].displayName, "Point #2")
    verifyEq(vals[0].val, 90f)
    verifyEq(vals[0].status, Status.fault)
    verifyEq(vals[0].get("curVal").val, 90f)

    // poll for changes - there should be none
    res = client.invoke(w.get("pollChanges").normalizedHref, ObixObj {})
    vals = res.get("values").list
    verifyEq(vals.size, 0)

    // poll refresh - get all three valid recs
    pt2   = commit(pt2, ["curVal":n(123f), "curStatus":"disabled"], Diff.transient)
    recA = commit(recA, ["foo":"bar"])
    res = client.invoke(w.get("pollRefresh").normalizedHref, ObixObj {})
    vals = res.get("values").list
    vals = vals.dup.sort |a, b| { a.displayName <=> b.displayName }
    verifyEq(vals.size, 3)
    verifyEq(vals[0].href, href(`rec/${pt2.id}/`))
    verifyEq(vals[0].val, 123f)
    verifyEq(vals[0].status, Status.disabled)
    verifyEq(vals[1].href, href(`rec/${recA.id}/`))
    verifyEq(vals[1].get("foo").val, "bar")
    verifyEq(vals[2].href, href(`rec/${recB.id}/`))

    // poll for changes - there should be none
    res = client.invoke(w.get("pollChanges").normalizedHref, ObixObj {})
    vals = res.get("values").list
    verifyEq(vals.size, 0)

    // change a, b
    recA = commit(recA, ["foo":"again"])
    recB = commit(recB, ["foo":"again"])

    // remove recB
    list = ObixObj { elemName = "list"; name = "hrefs" }
    list.add(ObixObj { val = this.href(`rec/${recB.id}/`) })
    list.add(ObixObj { val = this.href(`rec/badone/`) })
    res = client.invoke(w.get("remove").normalizedHref, ObixObj { add(list) })
    verifyWatchIds(w, [recA, pt2])

    // poll for changes - there should be just a (we removed b)
    res = client.invoke(w.get("pollChanges").normalizedHref, ObixObj {})
    vals = res.get("values").list
    verifyEq(vals.size, 1)
    verifyEq(vals[0].normalizedHref, lobbyUri + `rec/${recA.id}/`)
    verifyEq(vals[0].get("foo").val, "again")

    // remove watch
    verifyNotNull(proj.watch.get(w.href.path[-1]))
    res = client.invoke(w.get("delete").normalizedHref, ObixObj {})
    verifyNull(proj.watch.get(w.href.path[-1], false))

    // poll with removed watch
    try
    {
      res = client.invoke(w.get("pollChanges").normalizedHref, ObixObj {})
      fail
    }
    catch (ObixErr e)
    {
      verifyEq(e.contract.toStr, "obix:BadUriErr")
    }
  }

  private Void verifyWatch(ObixObj obj)
  {
    verifyEq(obj.contract.toStr, "obix:Watch")
    verifyEq(obj.get("add").elemName, "op")
    verifyEq(obj.get("remove").elemName, "op")
    verifyEq(obj.get("pollRefresh").elemName, "op")
    verifyEq(obj.get("pollRefresh").elemName, "op")

    w := proj.watch.get(obj.href.path[-1])
    verifyEq(w.lease, obj.get("lease").val)
  }

  private Void verifyWatchIds(ObixObj obj, Dict[] recs)
  {
    w := proj.watch.get(obj.href.path[-1])
    ids := w.list.sort.findAll |id| { id.toStr != "badone" }
    verifyEq(ids, recs.map|r->Ref|{r.id}.sort)
  }

  private Void verifyWatchUnresolvedErr(ObixObj obj, Uri uri)
  {
    verifyEq(obj.elemName, "err")
    verifyEq(obj.href, uri)
    verifyEq(obj.contract.toStr, "obix:BadUriErr")
  }

  Void verifyClientWatches()
  {
    // clear server points
    commit(this.pt1, ["curStatus":Remove.val], Diff.transient)
    commit(this.pt2, ["curStatus":"ok"], Diff.transient)

    // crate proxies for
    p1 := addClientProxy("Pt-1", "Bool",   href(`rec/${pt1.id}/`))
    p2 := addClientProxy("Pt-2", "Number", href(`rec/${pt2.id}/`))
    px := addClientProxy("Pt-X", "Number", href(`rec/$Ref.gen/`))

    // this.ptX is server, pX is client proxy
    verifyNotEq(p1.id, this.pt1.id)
    verifyNotEq(p2.id, this.pt2.id)

    // verify sync cur
    eval("obixSyncCur([$p1.id.toCode, $p2.id.toCode])")
    sync
    p1 = readById(p1.id); verifyEq(p1["curStatus"], "ok"); verifyEq(p1["curVal"], false)
    p2 = readById(p2.id); verifyEq(p2["curStatus"], "ok"); verifyEq(p2["curVal"], n(123))

    // change points, and verify sync cur again
    commit(readById(this.pt1.id), ["curVal":true], Diff.transient)
    commit(readById(this.pt2.id), ["curVal":n(93)], Diff.transient)
    eval("obixSyncCur([$p1.id.toCode, $p2.id.toCode])")
    sync
    p1 = readById(p1.id); verifyEq(p1["curStatus"], "ok"); verifyEq(p1["curVal"], true)
    p2 = readById(p2.id); verifyEq(p2["curStatus"], "ok"); verifyEq(p2["curVal"], n(93))

    // add watch on three proxies
    commit(readById(this.pt1.id), ["curVal":false], Diff.transient)
    commit(readById(this.pt2.id), ["curVal":n(555)], Diff.transient)
    w := proj.watch.open("test")
    w.addAll([p1.id, p2.id, px.id])
    sync
    // verify proxies
    p1 = readById(p1.id); verifyEq(p1["curStatus"], "ok"); verifyEq(p1["curVal"], false)
    p2 = readById(p2.id); verifyEq(p2["curStatus"], "ok"); verifyEq(p2["curVal"], n(555))
    px = readById(px.id); verifyEq(px["curStatus"], "fault"); verifyEq(px["curVal"], null)

    // verify server points
    verifyEq(proj.watch.list.size, 2)
    verifyEq(proj.watch.isWatched(this.pt1.id), true)
    verifyEq(proj.watch.isWatched(this.pt2.id), true)

    // make some changes
    pt1 = commit(this.pt1, ["curVal":true], Diff.transient)
    pt2 = commit(this.pt2, ["curVal":n(345, "ft")], Diff.transient)
    Actor.sleep(200ms)

    // verify proxies get changes
    p1 = readById(p1.id); verifyEq(p1["curStatus"], "ok"); verifyEq(p1["curVal"], true)
    p2 = readById(p2.id); verifyEq(p2["curStatus"], "ok"); verifyEq(p2["curVal"], n(345, "ft"))
    px = readById(px.id); verifyEq(px["curStatus"], "fault"); verifyEq(px["curVal"], null)

    // put local points into curStatus errror
    pt1 = commit(this.pt1, ["curStatus":"disabled"], Diff.transient)
    pt2 = commit(this.pt2, ["curStatus":"remoteDown"], Diff.transient)
    Actor.sleep(200ms)

    // verify proxies get changes
    p1 = readById(p1.id); verifyEq(p1["curStatus"], "remoteDisabled"); verifyEq(p1["curVal"], null)
    p2 = readById(p2.id); verifyEq(p2["curStatus"], "remoteDown"); verifyEq(p2["curVal"], null)
    px = readById(px.id); verifyEq(px["curStatus"], "fault"); verifyEq(px["curVal"], null)

    // unwatch pt1
    w.remove(p1.id)
    sync

    // verify server points
    verifyEq(proj.watch.list.size, 2)
    verifyEq(proj.watch.isWatched(pt1.id), false)
    verifyEq(proj.watch.isWatched(pt2.id), true)

    // close watch and verify closed on server side
    w.close
    sync
    verifyEq(proj.watch.list.size, 0)
    verifyEq(proj.watch.isWatched(pt1.id), false)
    verifyEq(proj.watch.isWatched(pt2.id), false)

    // reopen watch
    pt1 = commit(pt1, ["curVal":false, "curStatus":"ok"], Diff.transient)
    pt2 = commit(pt2, ["curVal":n(987, "m"), "curStatus":"ok"], Diff.transient)
    w = proj.watch.open("test 2")
    w.addAll([p1.id, p2.id])
    sync
    p1 = readById(p1.id); verifyEq(p1["curStatus"], "ok"); verifyEq(p1["curVal"], false)
    p2 = readById(p2.id); verifyEq(p2["curStatus"], "ok"); verifyEq(p2["curVal"], n(987, "m"))

    // find server side watch and force a close to simulate lease expired
    serverWatch := proj.watch.list.find |x| { x !== w }
    verifyEq(serverWatch.dis.startsWith("Obix Server:"), true, serverWatch.dis)
    serverWatch.close

    // now make some changes
    Actor.sleep(200ms)
    pt1 = commit(pt1, ["curVal":true], Diff.transient)
    pt2 = commit(pt2, ["curVal":n(339, "kW")], Diff.transient)
    Actor.sleep(200ms)

    // verify connector re-opens the watch to recover
    p1 = readById(p1.id); verifyEq(p1["curStatus"], "ok"); verifyEq(p1["curVal"], true)
    p2 = readById(p2.id); verifyEq(p2["curStatus"], "ok"); verifyEq(p2["curVal"], n(339, "kW"))
  }

  Void verifyWritables()
  {
    // we must add obixWriteLevel before it becomes writable
    res := client.read(href(`rec/${pt3.id}/`))
    verify(res.contract.uris.contains(`obix:Point`))
    verify(!res.contract.uris.contains(`obix:WritablePoint`))

    // now add obixWriteLevel and check again
    pt3 = commit(pt3, ["obixWritable": n(13)])
    res = client.read(href(`rec/${pt3.id}/`))
    verify(res.contract.uris.contains(`obix:Point`))
    verify(res.contract.uris.contains(`obix:WritablePoint`))

    // verify writePoint op
    op := res.get("writePoint")
    verifyEq(op.elemName, "op")
    verifyEq(op.in.toStr, "obix:WritePointIn")

    // verify before any writes
    proj.ext("hx.point")
    proj.sync
    eval("pointSetDef($pt3.id.toCode, 0)")
    proj.sync
    pt3 = readById(pt3.id)
    verifyEq(pt3["writeVal"], n(0))
    verifyEq(pt3["writeLevel"], n(17))

    // perform write
    writeUri := href(`rec/${pt3.id}/writePoint`)
    client.invoke(writeUri, ObixObj { ObixObj { name="value"; val = 932f },})
    proj.sync
    pt3 = readById(pt3.id)
    verifyEq(pt3["writeVal"], n(932))
    verifyEq(pt3["writeLevel"], n(13))

    // now write null/auto
    client.invoke(writeUri, ObixObj { ObixObj { name="value"; val = null },})
    proj.sync
    pt3 = readById(pt3.id)
    verifyEq(pt3["writeVal"], n(0))
    verifyEq(pt3["writeLevel"], n(17))

    // verify going thru proxy
    eval("""obixInvoke($conn.id.toCode, `$writeUri`, "<obj><real name='value' val='423'/></obj>")""")
    proj.sync
    pt3 = readById(pt3.id)
    verifyEq(pt3["writeVal"], n(423))
    verifyEq(pt3["writeLevel"], n(13))
  }

  Dict addClientProxy(Str dis, Str kind, Uri uri)
  {
    addRec(["dis":dis, "point":Marker.val, "kind":kind, "obixConnRef":conn.id, "obixCur":uri])
  }

  Void dump(Str title, ObixObj obj)
  {
    echo("######### $title ##########")
    obj.writeXml(Env.cur.out)
  }

//////////////////////////////////////////////////////////////////////////
// ObixUtil
//////////////////////////////////////////////////////////////////////////

  Void testToObix()
  {
    ts := DateTime.now

    verifyToObix(null,               "<obj isNull='true'/>")
    verifyToObix("foo",              "<str val='foo'/>")
    verifyToObix(n(123),             "<real val='123.0'/>")
    verifyToObix(n(123, "m"),        "<real val='123.0' unit='obix:units/meter'/>")
    verifyToObix(true,               "<bool val='true'/>")
    verifyToObix(`foo.txt`,          "<uri val='foo.txt'/>")
    verifyToObix(Date("2012-03-06"), "<date val='2012-03-06'/>")
    verifyToObix(Time(23, 15),       "<time val='23:15:00'/>")
    verifyToObix(ts,                 "<abstime val='$ts.toIso' tz='$ts.tz.fullName'/>")
    verifyToObix("<int val='3'/>",   "<int val='3'/>")
  }

  Void verifyToObix(Obj? val, Str expected)
  {
    obix := ObixUtil.toObix(val)
    s := StrBuf()
    obix.writeXml(s.out)
    actual := s.toStr.trim
    verifyEq(actual, expected)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  IHisExt hisExt() { proj.exts.his }

  static HisItem item(DateTime ts, Obj? val)
  {
    if (val is Num) val = Number.makeNum(val)
    return HisItem(ts, val)
  }

  static DateTime dt(Int y, Int m, Int d, Int h, Int min, TimeZone tz := TimeZone.utc)
  {
    DateTime(y, Month.vals[m-1], d, h, min, 0, 0, tz)
  }

  Uri href(Uri relative)
  {
    lobbyUri.plus(relative).relToAuth
  }

  Void sync()
  {
    proj.sync
    lib.conn(conn.id).sync
  }
}

