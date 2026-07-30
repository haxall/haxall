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
    doErrGrid
    doFiletypes
    doNav
    doWatches
    doHis
    doPointWrite
    doDefOps
    doOpWebFuncs
    doErrJson
    cleanup
  }

//////////////////////////////////////////////////////////////////////////
// Err JSON Envelope
//////////////////////////////////////////////////////////////////////////

  ** Failures in the HTTP processing itself - as opposed to a failure raised
  ** by the op function - return a real status code with a `sys.api::ApiErr`
  ** subtype encoded as clean JSON in both dialects.  The spec tag is the
  ** programmatic contract; the status code is advisory.
  Void doErrJson()
  {
    // unknown proj
    err := verifyErrJson(`/api/badProjName/about`, 404)
    verifyEq(err["spec"], "sys.api::UnknownProjErr")
    verifyEq(err["projName"], "badProjName")

    // unknown op
    err = verifyErrJson(`/api/$proj.name/badOpName`, 404)
    verifyEq(err["spec"], "sys.api::UnknownFuncErr")
    verifyEq(err["funcName"], "badOpName")

    // GET on an op with side effects
    err = verifyErrJson(`/api/$proj.name/eval?expr=now()`, 405)
    verifyEq(err["spec"], "sys.api::MethodNotAllowedErr")
    verifyEq(err["allow"], Obj?["POST"])

    // bad Xeto-Version header; allowed versions are ApiVersion scalar
    // tokens so the format stays open to non-integer versions later
    err = verifyErrJson(`/api/$proj.name/about`, 400, "7")
    verifyEq(err["spec"], "sys.api::UnsupportedVersionErr")
    verifyEq(err["allow"], Obj?["4", "5"])

    // non-numeric version header is rejected the same way
    err = verifyErrJson(`/api/$proj.name/about`, 400, "bogus")
    verifyEq(err["spec"], "sys.api::UnsupportedVersionErr")
  }

  ** Request uri and verify a JSON ApiErr body with the given status code
  Str:Obj? verifyErrJson(Uri uri, Int code, Str? version := null)
  {
    wc := c.toWebClient(uri)
    if (version != null) wc.reqHeaders["Xeto-Version"] = version
    wc.writeReq
    wc.readRes
    verifyEq(wc.resCode, code)
    verifyEq(wc.resHeaders["Content-Type"], "application/json")
    json := (Str:Obj?)JsonInStream(wc.resStr.in).readJson
    wc.close

    // every err carries the advisory status as a JSON integer plus a
    // human readable dis matching the status phrase
    verifyEq(json["status"], code)
    verifyEq(json["dis"], wc.resPhrase)
    verify((json["spec"] as Str).startsWith("sys.api::"))
    return json
  }

//////////////////////////////////////////////////////////////////////////
// opWeb Funcs
//////////////////////////////////////////////////////////////////////////

  ** The "ext" and "file" ops are serviced by `opWeb` marked funcs which
  ** read the web request and write the response themselves.  These tests
  ** must pass in both dialects: the v4 wire contract used here, and the
  ** v5 contract selected by the Xeto-Version header.  Since an opWeb func
  ** performs no request decoding or response encoding, its behavior is
  ** identical in both - which is exactly why they migrate first.
  Void doOpWebFuncs()
  {
    verifyOpWebSpecs
    verifyFileOp
    verifyExtOp
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

    // filetypes: the four grid formats
    g = c.callGrid("filetypes")
    [Symbol("filetype:zinc"), Symbol("filetype:trio"),
     Symbol("filetype:json"), Symbol("filetype:csv")].each |s| { verifyDefIn(g, s) }

    // ops: reports the def declared ops
    g = c.callGrid("ops")
    [Symbol("op:about"), Symbol("op:read"),
     Symbol("op:ops"), Symbol("op:filetypes")].each |s| { verifyDefIn(g, s) }

    // all four are GET-able and agree with their POST result
    ["defs", "libs", "ops", "filetypes"].each |op|
    {
      verifyEq(callAsGet(op).size, c.callGrid(op).size, op)
    }
  }

  Void verifyDefIn(Grid g, Symbol sym)
  {
    verifyNotNull(g.find |r| { r->def == sym }, sym.toStr)
  }

  ** Both funcs resolve to hx.api, carry opWeb, and take no parameters
  private Void verifyOpWebSpecs()
  {
    cx := makeContext(null)
    ["ext", "file"].each |n|
    {
      f := cx.ns.funcs.getAll(n).find |x| { x.meta.has("opWeb") }
      verifyNotNull(f, n)
      verifyEq(f.qname, "hx.api::Funcs.${n}")
      verifyEq(f.func.params.size, 0)
      verifyEq(f.meta.has("op"), true)
    }
  }

  ** GET downloads via FileWeblet; POST/PUT routes to the ext upload handler
  private Void verifyFileOp()
  {
    Actor.locals[ActorContext.actorLocalsKey] = makeContext(null)
    proj.sys.file.resolve(`/io/opweb.txt`).out.print("hello opWeb").close

    // GET downloads the file
    verifyEq(c.toWebClient(`file/io/opweb.txt`).getStr, "hello opWeb")

    // GET sets the identity headers which FileWeblet provides
    wc := c.toWebClient(`file/io/opweb.txt`)
    wc.writeReq; wc.readRes
    verifyEq(wc.resCode, 200)
    verifyNotNull(wc.resHeaders["ETag"])
    verifyNotNull(wc.resHeaders["Last-Modified"])
    etag := wc.resHeaders["ETag"]
    wc.resIn.readAllBuf; wc.close

    // conditional GET returns 304 Not Modified
    wc = c.toWebClient(`file/io/opweb.txt`)
    wc.reqHeaders["If-None-Match"] = etag
    wc.writeReq; wc.readRes
    verifyEq(wc.resCode, 304)
    wc.close

    // unknown file is 404
    verifyEq(webCode(`file/io/nope-not-here.txt`), 404)

    // a directory path is 404 (download requires a file)
    verifyEq(webCode(`file/io/`), 404)

    // methods other than GET/POST/PUT are 404
    verifyEq(webCode(`file/io/opweb.txt`, "DELETE"), 404)

    // upload is unsupported by the haxall file ext: FileExt does not
    // override uploadHandler so the base UploadHandler stub returns 404.
    // SkySpark's XFileExt and xb's XbFileExt do support it.
    verifyEq(webPut(`file/io/other.txt`, "x"), 404)
  }

  ** Re-dispatches to another ext's WebMod by rewriting req.mod/modBase
  private Void verifyExtOp()
  {
    // routes to hxd::HxdUserWeb which serves login.css
    wc := c.toWebClient(`ext/user/login.css`)
    wc.writeReq; wc.readRes
    verifyEq(wc.resCode, 200)
    verifyEq(wc.resHeaders["Content-Type"].startsWith("text/css"), true)
    verify(wc.resIn.readAllStr.size > 0)
    wc.close

    // the delegate sees its own modRel: HxdUserWeb 404s an unknown route
    verifyEq(webCode(`ext/user/notARoute`), 404)

    // unknown ext route is 404
    verifyEq(webCode(`ext/notAnExtRoute/`), 404)

    // empty route name is 404
    verifyEq(webCode(`ext/`), 404)
  }

  ** PUT the body to the uri and return the response status code
  Int webPut(Uri uri, Str body)
  {
    wc := c.toWebClient(uri)
    wc.reqMethod = "PUT"
    wc.reqHeaders["Content-Type"] = "text/plain"
    wc.reqHeaders["Content-Length"] = body.size.toStr
    wc.writeReq
    wc.reqOut.print(body).close
    wc.readRes
    code := wc.resCode
    try { wc.resIn.readAllBuf } catch (Err e) {}
    wc.close
    return code
  }

  ** Request the uri and return the response status code
  Int webCode(Uri uri, Str method := "GET")
  {
    wc := c.toWebClient(uri)
    wc.reqMethod = method
    wc.writeReq
    wc.readRes
    code := wc.resCode
    try { wc.resIn.readAllBuf } catch (Err e) {}
    wc.close
    return code
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
    verifyEq(about->haystackVersion,      proj.defs.lib("ph").version.toStr)
    verifyEq(about->whoami,               c.auth->user)
    verifyEq(about->tz,                   TimeZone.cur.name)
    verifyEq(about->productName,          sys.info.productName)
    verifyEq(about->productVersion,       sys.info.productVersion)
    verifyEq(about->vendorName,           sys.info.vendorName)
    verifyEq(about->vendorUri,            sys.info.vendorUri)
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
    db := proj.db
    verifyEq(db.readCount(Filter("foo")), 0)
    g := c.callGrid("commit", Etc.makeMapGrid(["commit":"add"], ["dis":"Commit Test", "foo":m]))
    r := g.first as Dict
    verifyEq(db.readCount(Filter("foo")), 1)
    verifyDictEq(db.read(Filter("foo")), r)

    // update
    g = c.callGrid("commit", Etc.makeMapGrid(["commit":"update"], ["id":r.id, "mod":r->mod, "bar":"baz"]))
    r = readById(r.id)
    verifyEq(r["bar"], "baz")
    verifyDictEq(r, g.first)

    // update transient
    g = c.callGrid("commit", Etc.makeMapGrid(["commit":"update", "transient":m], ["id":r.id, "mod":r->mod, "curVal":n(123)]))
    r = readById(r.id)
    verifyEq(r["curVal"], n(123))

    // update force
    g = c.callGrid("commit", Etc.makeMapGrid(["commit":"update", "force":m], ["id":r.id, "mod":DateTime.nowUtc, "forceIt":"forced!"]))
    r = readById(r.id)
    verifyEq(r["forceIt"], "forced!")

    // remove
    g = c.callGrid("commit", Etc.makeMapGrid(["commit":"remove"], ["id":r.id, "mod":r->mod]))
    verifyEq(db.readById(r.id, false), null)
  }

//////////////////////////////////////////////////////////////////////////
// Gets
//////////////////////////////////////////////////////////////////////////

  ** Verify the api ext is resolvable by name -- both ApiWeb.toErrGrid
  ** and HxApiOp.toErrGrid look it up for the "disableErrTrace" setting.
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

  Void doGets()
  {
    // these ops are ok
    verifyEq(callAsGet("about").first->productName, sys.info.productName)
    verifyEq(callAsGet("defs").size, c.callGrid("defs").size)
    verifyEq(callAsGet("libs").size, c.callGrid("libs").size)
    verifyEq(callAsGet("filetypes").size, c.callGrid("filetypes").size)
    verifyEq(callAsGet("ops").size, c.callGrid("ops").size)
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

    // ?filetype and ?format query params select the response encoding
    verifyGridEq(callAsGetWith("read?filter=id&filetype=trio", "trio"), c.readAll("id"))
    verifyGridEq(callAsGetWith("read?filter=id&format=trio",   "trio"), c.readAll("id"))
    verifyGridEq(callAsGetWith("read?filter=id&filetype=json", "json"), c.readAll("id"))
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

}

