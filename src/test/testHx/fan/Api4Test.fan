//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Jun 2021  Brian Frank  Creation
//

using concurrent
using inet
using util
using web
using xeto
using haystack
using auth
using axon
using hx

**
** Api4Test tests the v4 legacy pre-xeto protocol (Haystack 2.0 - 4.0).
** Version 4 is assumed when the Xeto-Version header is undefined.
**
class Api4Test : ApiTest
{
  @HxTestProj
  Void test()
  {
    init
    doCommon      // tests which behave identically in both dialects
    doRead4       // v4 read takes a filter/id request grid
    doGets        // v4 GET args are zinc encoded query params
    doQnames      // ops may be addressed by qualified name
    doVersionParam // version selectable by query param
    doErrGrid     // v4 reports func errors as 200 + an err grid
    doFiletypes   // v4 zinc/csv/json content negotiation
    doDefOps      // pre-xeto def system; v4 only
    cleanup
  }

//////////////////////////////////////////////////////////////////////////
// Dialect Hooks
//////////////////////////////////////////////////////////////////////////

  override ApiVersion version() { ApiVersion.v4 }

  ** Version 4 encodes the args as a single row request grid and decodes
  ** the response as a grid
  override Obj? callOp(Client c, Str op, Str:Obj args)
  {
    c.callGrid(op, Etc.makeMapGrid(null, args))
  }

//////////////////////////////////////////////////////////////////////////
// Read
//////////////////////////////////////////////////////////////////////////

  private Void doRead4()
  {
    verifyRead(a)
    verifyRead(b)
    verifyRead(c)
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
    verifyDictEq(g[-1], Etc.dict0)
    verifyErr(UnknownRecErr#) { c.readByIds([siteA.id, Ref.gen]) }

    // raw read by filter
    g = c.callGrid("read", Etc.makeMapGrid(null, ["filter":"area >= 20000"]))
    verifyDictsEq(g.toRows, [siteA, siteB], false)

    // raw read by filter with limit
    g = c.callGrid("read", Etc.makeMapGrid(null, ["filter":"site", "limit":n(2)]))
    verifyEq(g.size, 2)

    // raw read by id
    g = c.callGrid("read", Etc.makeListGrid(null, "id", null, [Ref.gen, siteB.id, Ref.gen, siteC.id]))
    verifyDictEq(g[0], Etc.dict0)
    verifyDictEq(g[1], siteB)
    verifyDictEq(g[2], Etc.dict0)
    verifyDictEq(g[3], siteC)
  }

//////////////////////////////////////////////////////////////////////////
// Gets
//////////////////////////////////////////////////////////////////////////

  ** Verify the api ext is resolvable by name -- ApiPipeline.writeErrGrid
  ** looks it up for the "disableErrTrace" setting.
  ** Also verify an op error returns an err grid with the trace by default.
  Void doErrGrid()
  {
    verifyNotNull(makeContext(null).ext("hx.api", false))

    // eval an expression which throws; default settings keep the trace
    wc := c.toWebClient(`eval`)
    wc.reqMethod = "POST"
    wc.reqHeaders["Content-Type"] = "text/zinc"
    body := Buf().print(Str<|ver:"3.0"
                             expr
                             "thisFuncDoesNotExist()"
                             |>).flip.readAllStr
    wc.reqHeaders["Content-Length"] = body.size.toStr
    wc.writeReq
    wc.reqOut.print(body).close
    wc.readRes
    grid := ZincReader(wc.resStr.in).readGrid
    verify(grid.meta.has("err"))
    verify(grid.meta.has("errTrace"))
    verifyEq(grid.meta->errTrace.toStr.contains("Trace disabled"), false)
  }

  ** The GET/POST matrix: an op with <noSideEffects> answers GET with its
  ** args as query params, everything else is POST only.  The method rules
  ** live in ApiDispatch so verifyOpMethods is shared by both dialects;
  ** what is v4 specific here is the zinc encoding of the query values and
  ** the result grid.
  Void doGets()
  {
    // ops which allow GET
    verifyOpMethods("about", true)
    verifyOpMethods("read",  true, "filter=id")
    verifyEq(callAsGet("about").first->productName, sys.info.productName)
    verifyEq(callAsGet("read?filter=id").size, c.readAll("id").size)

    // ops which are POST only
    verifyOpMethods("eval",   false, "expr=now()")
    verifyOpMethods("commit", false, "id=@foo")

    // Commented out until finished
    verifyEq(callAsGet("defs").size, c.callGrid("defs").size)
    //verifyEq(callAsGet("libs").size, c.callGrid("libs").size)
    //verifyEq(callAsGet("filetypes").size, c.callGrid("filetypes").size)
    verifyEq(callAsGet("ops").size, c.callGrid("ops").size)
  }

  Grid callAsGet(Str path)
  {
    str := c.toWebClient(path.toUri).getStr
    return ZincReader(str.in).readGrid
  }

//////////////////////////////////////////////////////////////////////////
// Op Resolution
//////////////////////////////////////////////////////////////////////////

  ** An op may be addressed by its qualified name, which is never
  ** ambiguous where a simple name can collide across libs.  This is what
  ** `sys.api::OpInfo.qname` reports as the safe way to call.
  **
  ** NOTE: a qname bypasses the ApiDispatchV4Op specials table, which is
  ** keyed by simple name.  So "sys.api::read" reaches the axon func
  ** directly rather than ApiDispatchV4Read and the two take different
  ** args; only the simple name works for those five legacy ops.
  Void doQnames()
  {
    // the qname is the axon style "lib::name", not the spec's own
    // "lib::Funcs.name".  The uri must be built absolute: as a relative
    // fragment the colon pair would parse as a scheme separator.
    verifyEq(getQname("sys.api::about").first->productName,
             callAsGet("about").first->productName)

    // the spec's own qname form is not what the api accepts
    verifyEq(codeQname("sys.api::Funcs.about"), 404)

    // a qname which is not a func is unknown, not ambiguous
    verifyEq(codeQname("sys.api::AboutInfo"), 404)
    verifyEq(codeQname("no.such.lib::nope"), 404)

    // the method rules still apply to a qname
    verifyEq(codeQname("hx.api::eval?expr=now()"), 405)
  }

  ** GET an op by qualified name and read the result grid
  Grid getQname(Str qname)
  {
    str := qnameClient(qname).getStr
    return ZincReader(str.in).readGrid
  }

  ** GET an op by qualified name and return the status code
  Int codeQname(Str qname)
  {
    wc := qnameClient(qname)
    wc.writeReq
    wc.readRes
    code := wc.resCode
    try { wc.resIn.readAllBuf } catch (Err e) {}
    wc.close
    return code
  }

  ** Authenticated web client for an op addressed by qualified name.  The
  ** uri must be built absolute: as a relative fragment the qname's colon
  ** pair would parse as a scheme separator.
  private WebClient qnameClient(Str qname)
  {
    c.auth.prepare(WebClient((uri.toStr + qname).toUri))
  }

//////////////////////////////////////////////////////////////////////////
// Version Selection
//////////////////////////////////////////////////////////////////////////

  ** The protocol version may be selected by the "version" query param as
  ** well as the Xeto-Version header, so a v5 request can be made from a
  ** browser or curl without setting headers.  The param must not leak
  ** into the op's arguments.
  Void doVersionParam()
  {
    // v4 explicitly by param
    verifyEq(callAsGet("about?xeto-version=4").first->productName, sys.info.productName)

    // a control param is never passed to the op: "read" would fail if
    // "xeto-version" arrived as an argument alongside the filter
    g := callAsGet("read?filter=site&xeto-version=4")
    verifyEq(g.size, 3)

    // an unsupported version is rejected the same way as the header
    err := verifyErrJson(`/api/$proj.name/about?xeto-version=7`, 400)
    verifyEq(err["spec"], "sys.api::UnsupportedVersionErr")
    verifyEq(err["allow"], Obj?["4", "5"])

    // the param wins over the header when both are given
    wc := c.toWebClient(`about?xeto-version=7`)
    wc.reqHeaders["Xeto-Version"] = "4"
    wc.writeReq
    wc.readRes
    verifyEq(wc.resCode, 400)
    wc.close

    // an unprefixed "version" is an op argument, not protocol control:
    // it reaches the op rather than being consumed by the pipeline
    verifyEq(callAsGet("about?version=7").first->productName, sys.info.productName)
  }

//////////////////////////////////////////////////////////////////////////
// Filetypes
//////////////////////////////////////////////////////////////////////////

  Void doFiletypes()
  {
    req := Etc.makeMapGrid(null, ["expr": "today()", "ts": DateTime.now])
    res := Etc.toGrid(Date.today)

    // standard mime types
    verifyGridEq(callMime("eval", req, "text/zinc", null), res)
    verifyGridEq(callMime("eval", req, "text/zinc", "text/zinc"), res)
    verifyGridEq(callMime("eval", req, "text/trio", "text/trio"), res)
    verifyGridEq(callMime("eval", req, "text/csv",  "text/zinc"), res)
    verifyGridEq(callMime("eval", req, "application/json", "application/json"), res)

    // cross encodings
    verifyGridEq(callMime("eval", req, "text/zinc", "application/json"), res)
    verifyGridEq(callMime("eval", req, "application/json", "text/zinc"), res)
    // csv is lossy: scalars come back as Str, so verify the encoded value
    verifyEq(callMime("eval", req, "text/trio", "text/csv")->first->val, Date.today.toStr)

    // charset params are ignored for lookup
    verifyGridEq(callMime("eval", req, "text/zinc; charset=utf-8", "text/zinc; charset=utf-8"), res)

    // hayson v3 via explicit version param
    verifyGridEq(callMime("eval", req, "application/json;version=3", "application/json;version=3"), res)
    verifyGridEq(callMime("eval", req, "application/json;version=4", "application/json;version=4"), res)
    verifyGridEq(callMime("eval", req, "application/json;version=3", "application/json"), res)

    // vnd.haystack+{filetype}
    verifyGridEq(callMime("eval", req, "application/vnd.haystack+zinc", "application/vnd.haystack+zinc"), res)
    verifyGridEq(callMime("eval", req, "application/vnd.haystack+trio", "application/vnd.haystack+trio"), res)
    verifyGridEq(callMime("eval", req, "application/vnd.haystack+csv",  "application/vnd.haystack+zinc"), res)
    verifyGridEq(callMime("eval", req, "application/vnd.haystack+json", "application/vnd.haystack+json"), res)
    verifyGridEq(callMime("eval", req, "application/vnd.haystack+json;version=3", "application/vnd.haystack+json;version=3"), res)

    // unsupported/missing content types
    verifyEq(callMime("eval", req, null,         "text/zinc"), 415)
    verifyEq(callMime("eval", req, "text/plain", "text/zinc"), 415)
    verifyEq(callMime("eval", req, "text/foo",   "text/zinc"), 415)
    verifyEq(callMime("eval", req, "text/zinc",  "text/plain"), 406)
    verifyEq(callMime("eval", req, "text/zinc",  "text/foo"), 406)

    // write-only filetypes cannot be used to post a request
    verifyEq(callMime("eval", req, "text/html",  "text/zinc"), 415)

    // the response encoding is selected by ?xeto-filetype.  The bare
    // ?filetype and ?format forms it replaced were undocumented debugging
    // aids, so they are simply gone rather than kept as v4 aliases.
    verifyGridEq(callAsGetWith("read?filter=id&xeto-filetype=trio", "trio"), c.readAll("id"))
    verifyGridEq(callAsGetWith("read?filter=id&xeto-filetype=json", "json"), c.readAll("id"))
  }

  ** Post reqGrid encoded per reqMime and decode the response per resMime.
  ** Returns the response grid or the status code if not 200.
  Obj callMime(Str op, Grid reqGrid, Str? reqMimeStr, Str? resMimeStr)
  {
    reqMime := MimeType(reqMimeStr ?: "", false)
    resMime := MimeType(resMimeStr ?: "", false)

    // encode request using the request mime type; fallback to zinc so we
    // can still post a body when testing unsupported content types
    reqType := (reqMime == null ? null : Filetype.byMime(reqMime, false)) ?: Filetype.byName("zinc")
    if (!reqType.hasReader) reqType = Filetype.byName("zinc")
    reqBuf := Buf()
    reqType.writer(reqBuf.out, jsonVersionOpts(reqMime)).writeGrid(reqGrid)

    wc := c.toWebClient(op.toUri)
    wc.reqMethod = "POST"
    if (reqMimeStr != null) wc.reqHeaders["Content-Type"] = reqMimeStr
    if (resMimeStr != null) wc.reqHeaders["Accept"] = resMimeStr
    wc.reqHeaders["Content-Length"] = reqBuf.size.toStr

    wc.writeReq
    wc.reqOut.writeBuf(reqBuf.seek(0)).close

    wc.readRes
    if (wc.resCode == 100) wc.readRes
    if (wc.resCode != 200) { wc.close; return wc.resCode }
    resBuf := wc.resIn.readAllBuf
    wc.close

    resType := (resMime == null ? null : Filetype.byMime(resMime, false)) ?: Filetype.byName("zinc")
    return resType.reader(resBuf.seek(0).in, jsonVersionOpts(resMime)).readGrid
  }

  ** GET the given path and decode the response using given filetype name
  Grid callAsGetWith(Str path, Str filetype)
  {
    str := c.toWebClient(path.toUri).getStr
    return Filetype.byName(filetype).reader(str.in).readGrid
  }

  ** Hayson v3 is selected by an explicit ";version=3" mime param
  static Dict jsonVersionOpts(MimeType? mime)
  {
    mime?.params?.get("version") == "3" ? Etc.dict1("v3", Marker.val) : Etc.dict0
  }

//////////////////////////////////////////////////////////////////////////
// Nav
//////////////////////////////////////////////////////////////////////////

  Void doNav()
  {
    if (sys.info.type.isSkySpark) return

    g := c.callGrid("nav", Etc.makeMapGrid(null, Str:Obj[:]))
    verifyEq(g.size, 3)
    verifyEq(g[0].dis, "A")
    verifyEq(g[0].id, g[0]["navId"])

    g = c.callGrid("nav", Etc.makeMapGrid(null, Str:Obj["navId":g[0].id]))
    verifyEq(g.size, 1)
    verifyEq(g[0].dis, "A1")
    verifyEq(g[0].id, g[0]["navId"])

    g = c.callGrid("nav", Etc.makeMapGrid(null, Str:Obj["navId":g[0].id]))
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
    w := proj.watch
    verifyEq(w.isWatched(siteA.id), false)
    verifyEq(w.isWatched(eqA1.id), false)
    res := c.callGrid("watchSub", Etc.makeListGrid(["watchDis":"test", "lease":n(17, "min")], "id", null, [siteA.id, eqA1.id]))
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
    res = c.callGrid("watchPoll", Etc.makeEmptyGrid(["watchId": watchId]))

    // haystack: watchPoll
    eqA1 = commit(eqA1, ["foo":n(123)])
    res = c.callGrid("watchPoll", Etc.makeEmptyGrid(["watchId": watchId]))
    verifyEq(res.size, 1)
    verifyEq(res[0].id, eqA1.id)
    verifyEq(res[0]->foo, n(123))

    // haystack: watchUnsub
    res = c.callGrid("watchUnsub", Etc.makeListGrid(["watchId": watchId], "id", null, [eqA1.id]))
    verifyEq(w.isWatched(siteA.id), true)
    verifyEq(w.isWatched(eqA1.id), false)

    // haystack: watchUnsub
    res = c.callGrid("watchUnsub", Etc.makeEmptyGrid(["watchId": watchId, "close":true]))
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
    res := c.callGrid("hisWrite", req)

    // batch hisWrite to ptA, ptB
    gb := GridBuilder()
    ts := Date("2023-05-13").midnight
    gb.addCol("ts").addCol("v0", ["id":ptA.id.noDis]).addCol("v1", ["id":ptB.id.noDis])
    gb.addRow([ts + 0hr, n(100), n(200)])
    gb.addRow([ts + 1hr, null,   n(201)])
    gb.addRow([ts + 2hr, n(102), null])
    gb.addRow([ts + 3hr, n(103), n(203)])
    res = c.callGrid("hisWrite", gb.toGrid)

    // verify ptA got written
    proj.sync
    ptA = proj.readById(ptA.id)
    ptB = proj.readById(ptB.id)
    verifyEq(ptA["hisSize"], n(9))
    verifyEq(ptB["hisSize"], n(3))

    // hisRead from ptA (yesterday)
    res = c.callGrid("hisRead", Etc.makeMapGrid(null, ["id":ptA.id.noDis, "range":"yesterday"]))
    verifyEq(res.size, 3)
    verifyEq(res.meta->hisStart, yesterday)
    verifyEq(res.meta->hisEnd, today)
    verifyDictEq(res[0], items[0])
    verifyDictEq(res[1], items[1])
    verifyDictEq(res[2], items[2])

    // hisRead from ptA (today)
    res = c.callGrid("hisRead", Etc.makeMapGrid(null, ["id":ptA.id.noDis, "range":"today"]))
    verifyEq(res.size, 3)
    verifyDictEq(res[0], items[3])
    verifyDictEq(res[1], items[4])
    verifyDictEq(res[2], items[5])

    // hisRead from ptA (range)
    res = c.callGrid("hisRead", Etc.makeMapGrid(null, ["id":ptA.id.noDis, "range":items[4].ts.toStr]))
    verifyEq(res.size, 2)
    verifyDictEq(res[0], items[-2])
    verifyDictEq(res[1], items[-1])

    // batch hisRead
    gb = GridBuilder().setMeta(["range":"2023-05-13"]).addCol("id")
    gb.addRow1(ptA.id.noDis)
    gb.addRow1(ptB.id.noDis)
    res = c.callGrid("hisRead", gb.toGrid)
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
    res = c.callGrid("hisRead", gb.toGrid)
    verifyEq(res.size, 3)
    verifyEq(res.meta->hisStart.toStr, tsM1.toStr)
    verifyEq(res.meta->hisEnd.toStr, tsM1.plus(1day).toStr)
    verifyEq(res[0]->ts->tz.toStr, "Chicago")
    verifyDictEq(res[0], ["ts":tsM1 + 0hr, "v0":null,   "v1":n(201)])
    verifyDictEq(res[1], ["ts":tsM1 + 1hr, "v0":n(102), "v1":null])
    verifyDictEq(res[2], ["ts":tsM1 + 2hr, "v0":n(103), "v1":n(203)])

    // hisRead with span using Chicago timezone, results in point's tz
    res = c.callGrid("hisRead", Etc.makeMapGrid(null, ["id":ptA.id.noDis, "range":tsM1.toStr + "," +  tsM1.plus(1day).toStr]))
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

    res := c.callGrid("pointWrite", Etc.makeMapGrid(null, ["id":pt.id, "level":n(16), "val":n(160)]))
    res = c.callGrid("pointWrite", Etc.makeMapGrid(null, ["id":pt.id, "level":n(8), "val":n(80), "duration":n(1, "hr")]))
    res = c.callGrid("pointWrite", Etc.makeMapGrid(null, ["id":pt.id]))

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

//////////////////////////////////////////////////////////////////////////
// Def Ops
//////////////////////////////////////////////////////////////////////////

  ** The defs/libs/ops/filetypes ops expose the legacy def namespace.  They
  ** have no v5 equivalent since defs are being removed, so this pins down
  ** the v4 contract before any rewrite.
  Void doDefOps()
  {
    // defs: filter selects a single def
    g := c.callGrid("defs", Etc.makeMapGrid(null, ["filter":"def==^ahu"]))
    verifyEq(g.size, 1)
    verifyEq(g.first->def, Symbol("ahu"))

    // defs: filter matching nothing is an empty grid, not an error
    g = c.callGrid("defs", Etc.makeMapGrid(null, ["filter":"def==^noSuchDefAnywhere"]))
    verifyEq(g.size, 0)
    verifyEq(g.meta.has("incomplete"), false)

    // defs: limit truncates and flags the result via grid meta
    g = c.callGrid("defs", Etc.makeMapGrid(null, ["filter":"tagOn", "limit":n(3)]))
    verifyEq(g.size, 3)
    verifyEq(g.meta.has("incomplete"), true)
    verifyEq(g.meta->limit, n(3))

    // defs: a limit larger than the result set does not flag incomplete
    g = c.callGrid("defs", Etc.makeMapGrid(null, ["filter":"def==^ahu", "limit":n(100)]))
    verifyEq(g.size, 1)
    verifyEq(g.meta.has("incomplete"), false)

    // libs: includes the core libs
    g = c.callGrid("libs")
    verifyDefIn(g, Symbol("lib:ph"))
    verifyDefIn(g, Symbol("lib:hx"))

    // filetypes and ops have no func at all so they 404, and the GET
    // parity check needs <noSideEffects> on defs/libs.  Commented out
    // until the def ops are given implementations.
    //g = c.callGrid("filetypes")
    //[Symbol("filetype:zinc"), Symbol("filetype:trio"),
    // Symbol("filetype:json"), Symbol("filetype:csv")].each |s| { verifyDefIn(g, s) }
    //
    // ops: v4 gets the legacy def format from the ApiDispatchV4Ops hook,
    // never the sys.api::ops func which serves v5.  The v5 shape is
    // asserted by Api5Test.doOpsFunc.
    g = c.callGrid("ops")
    [Symbol("op:about"), Symbol("op:read"),
     Symbol("op:ops"), Symbol("op:filetypes")].each |s| { verifyDefIn(g, s) }
    //
    //["defs", "libs", "ops", "filetypes"].each |op|
    //{
    //  verifyEq(callAsGet(op).size, c.callGrid(op).size, op)
    //}
  }

  Void verifyDefIn(Grid g, Symbol sym)
  {
    verifyNotNull(g.find |r| { r->def == sym }, sym.toStr)
  }

//////////////////////////////////////////////////////////////////////////

}

