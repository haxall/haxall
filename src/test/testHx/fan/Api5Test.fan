//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2025  Brian Frank  Creation
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
** Api5Test tests the v5 xeto protocol (Haystack 5.0) selected by the
** Xeto-Version header.
**
class Api5Test : ApiTest
{
  @HxTestProj
  Void test()
  {
    doOpsFunc

    init
    doCommon      // tests which behave identically in both dialects
    doWriteRes
    doReads
    doEval
    doAboutTyped
    doLibsFunc
    doFiletypesFunc
    doGridOps
    doUpload
    doNegotiation
    cleanup
  }

//////////////////////////////////////////////////////////////////////////
// Write Response
//////////////////////////////////////////////////////////////////////////

  ** The response half of the dispatch is implemented ahead of the request
  ** half, so exercise it with ops which need no args decoded.  Version 5
  ** answers clean JSON with no grid envelope.
  Void doWriteRes()
  {
    traceSection("doWriteRes")
    // about takes no args, so it exercises the response half alone; it
    // answers a typed AboutInfo instance whose spec tag rides the wire
    json := (Str:Obj?)postJson(`about`)
    verifyEq(json["spec"], "sys.api::AboutInfo")
    verifyEq(json["whoami"], "charlie")
    verifyEq(json["tz"], TimeZone.cur.name)
    verifyEq(json["productName"], "Haxall")

    // a POST arg is decoded against its declared param spec: the id is a
    // JSON string which must come back a Ref, not a Str
    rec := (Str:Obj?)postJson(`readById`, """{"id":"$siteA.id.id"}""")
    verifyEq(rec["dis"], "A")

    // an omitted param falls back to its declared default
    verifyEq(postJson(`readById`, """{"id":"bad-id", "checked":false}"""), null)

    // a maybe param may be omitted entirely and defaults to null
    verifyEq(postJson(`readById`, """{"checked":false}"""), null)

    // a missing required arg is a 400, not a null passed to the func
    verifyReqErr(`read`, "{}", 400, "sys.api::InvalidArgsErr")

    // an op whose params all default may be posted with no body at all,
    // whitespace or otherwise; only a non-blank body is parsed as JSON
    verifyEq(postJson(`about`, "")->get("whoami"), "charlie")
    verifyEq(postJson(`about`, "\n")->get("whoami"), "charlie")

    // GET takes its args as bare query params so URLs stay readable, and
    // decodes each against its param spec just as POST does
    rec = (Str:Obj?)getJson(`readById?id=$siteA.id.id`)
    verifyEq(rec["dis"], "A")
    verifyEq(getJson(`readById?id=bad-id&checked=false`), null)

    // a control param is reserved for the request and is not a func arg
    rec = (Str:Obj?)getJson(`readById?id=$siteA.id.id&xeto-version=5`)
    verifyEq(rec["dis"], "A")

    // plain JSON decodes against the param specs: the id as a bare
    // string and the level as a bare number.  The val position is
    // dynamically typed by the point's own kind, which no position
    // spec can supply - that is exactly what the box is for
    g := (Str:Obj?)postJson(`pointWrite`,
      """{"id":"$ptW.id.id", "level":16, "val":{"spec":"sys::Number", "val":"160"}}""")
    verifyEq(g["spec"], "sys::Grid")
  }

  ** POST an op and decode the JSON response, verifying the version 5
  ** response envelope along the way
  private Obj? postJson(Uri op, Str body := "")
  {
    wc := c.toWebClient(op)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/json"
    wc.postStr(body)
    resBody := wc.resStr
    wc.close
    trace(wc, body, resBody)
    verifyEq(wc.resCode, 200)
    verifyEq(wc.resHeaders["Content-Type"], "application/json")
    verifyEq(wc.resHeaders["Xeto-Version"], "5")
    return JsonInStream(resBody.in).readJson
  }

  ** GET an op and decode the JSON response
  private Obj? getJson(Uri op)
  {
    wc := c.toWebClient(op)
    setVersionHeader(wc)
    wc.writeReq
    wc.readRes
    verifyEq(wc.resCode, 200)
    verifyEq(wc.resHeaders["Xeto-Version"], "5")
    resBody := wc.resStr
    wc.close
    trace(wc, null, resBody)
    return JsonInStream(resBody.in).readJson
  }

  ** Verify a bad request reports the given status and ApiErr spec
  private Void verifyReqErr(Uri op, Str body, Int code, Str spec)
  {
    wc := c.toWebClient(op)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/json"
    wc.postStr(body)
    verifyResErr(wc, body, code, spec)
  }

  ** Verify the response reports the given status and ApiErr JSON body;
  ** call after the exchange with the request body for the trace
  private Void verifyResErr(WebClient wc, Str? reqBody, Int code, Str spec)
  {
    verifyEq(wc.resCode, code)
    verifyErrVersionHeader(wc)
    resBody := wc.resStr
    wc.close
    trace(wc, reqBody, resBody)
    json := (Str:Obj?)JsonInStream(resBody.in).readJson
    verifyEq(json["spec"], spec)
    verifyEq(json["status"], code)
  }

//////////////////////////////////////////////////////////////////////////
// Ops
//////////////////////////////////////////////////////////////////////////

  ** The v5 "ops" format is a quick listing for debugging and discovery,
  ** deliberately not a machine readable schema - the spec op serves that
  ** purpose.  Version 4 clients get the legacy def format from
  ** ApiDispatchV4Ops instead, which never reaches this function.
  Void doOpsFunc()
  {
    g := (Grid)eval("ops()")

    // every row must validate against the OpInfo spec
    setupContext
    ns := proj.ns
    opInfo := ns.spec("sys.api::OpInfo")
    verifyEq(g.meta->of, Ref("sys.api::OpInfo"))
    g.each |row|
    {
      verifyEq(ns.validate(row, opInfo).hasErrs, false, row->qname)
    }

    // the listing is qname, doc, noSideEffects, signature -- not a
    // machine readable schema; the spec op serves that purpose
    ["qname", "doc", "noSideEffects", "signature"].each |c|
    {
      verifyNotNull(g.col(c, false), c)
    }
    verifyNull(g.col("params", false))
    verifyNull(g.col("returns", false))

    // rows are sorted by qname so the listing is stable
    verify(g.size > 0)
    verifyEq(g.toRows.map |r->Str| { r->qname },
             g.toRows.map |r->Str| { r->qname }.dup.sort)

    // about: no params, typed result, GET-able
    about := verifyOpRow(g, "sys.api::about")
    verifyEq(about->signature, "() -> AboutInfo")
    verifyEq(about.has("noSideEffects"), true)

    // close: no params, no result, POST only
    close := verifyOpRow(g, "sys.api::close")
    verifyEq(close->signature, "() -> None")
    verifyEq(close.has("noSideEffects"), false)

    // read: a required filter plus a defaulted checked flag
    read := verifyOpRow(g, "sys.api::read")
    verifyEq(read->signature, "(filter: Filter, checked: Bool = true) -> Dict")

    // readById: "id" is nullable so the signature marks it with ? and does NOT
    // report a bogus default of @x inherited from the Ref type's meta
    byId := verifyOpRow(g, "sys.api::readById")
    verifyEq(byId->signature, "(id: Ref?, checked: Bool = true) -> Dict")

    // doc is the first sentence only, never a mid-sentence cut and
    // never the whole hard wrapped paragraph
    verifyEq(about->doc, "Return summary information about the server")
    verifyEq(read->doc, "Read the first entity which matches [filter](ph.doc::Filters)")
  }

  private Dict verifyOpRow(Grid g, Str qname)
  {
    row := g.find |r| { r->qname == qname }
    verifyNotNull(row, qname)
    return row
  }

//////////////////////////////////////////////////////////////////////////
// Dialect Hooks
//////////////////////////////////////////////////////////////////////////

  override ApiVersion version() { ApiVersion.v5 }

  ** Version 5 encodes the args as a JSON dict and decodes clean JSON
  override Obj? callOp(Client c, Str op, Str:Obj args)
  {
    call(c, op, args)
  }

  ** Version 5 passes the request grid as the named "req" arg encoded
  ** per the Jeto grid rules
  override Grid callGridOp(Client c, Str op, Grid req)
  {
    call(c, op, Etc.dict1("req", req))
  }

  ** Version 5 models the watchPoll parameters as named args
  override Grid callWatchPoll(Client c, Str watchId, Bool refresh := false)
  {
    args := Str:Obj["watchId":watchId]
    if (refresh) args["refresh"] = m
    return call(c, "watchPoll", args)
  }

//////////////////////////////////////////////////////////////////////////
// Eval
//////////////////////////////////////////////////////////////////////////

  Void doEval()
  {
    traceSection("doEval")
    verifyEval(a)
    verifyEval(b)
    verifyEval(c)
  }

  ** eval declares 'returns: Obj?', so the result carries no spec the client
  ** could decode against.  The codec boxes at auto, so a value whose plain
  ** form could not be recovered names its own spec and survives the trip:
  ** the box is what stands in for the type the position does not supply.
  ** Version 4 wrapped this same value in a grid.
  private Void verifyEval(Client c)
  {
    verifyCall(c, "eval", ["expr":"today()"], Date.today)
    verifyCall(c, "eval", ["expr":"true"], true)

    // Axon arithmetic yields a Number, which an untyped position cannot
    // recover from a bare JSON number - that would decode as Int - so auto
    // boxes it too
    verifyCall(c, "eval", ["expr":"2 + 3"], n(5))

    // these need a spec to recover their plain form, so auto boxes them
    verifyCall(c, "eval", ["expr":"marker()"], Marker.val)
    verifyCall(c, "eval", ["expr":"na()"], NA.val)
    verifyCall(c, "eval", ["expr":"1kW"], n(1, "kW"))
  }

//////////////////////////////////////////////////////////////////////////
// Reads
//////////////////////////////////////////////////////////////////////////

  ** The modeled read ops; version 4 serves these shapes through its
  ** read special, so only version 5 exercises the modeled params
  Void doReads()
  {
    traceSection("doReads")
    // read: first match as a dict, null on unchecked miss
    rec := (Dict)call(c, "read", Etc.dict1("filter", "site and dis==\"B\""))
    verifyEq(rec["id"], siteB.id)
    verifyEq(call(c, "read", Etc.dict2("filter", "notThere", "checked", false)), null)

    // readAll: every match as a grid, opts limit
    g := (Grid)call(c, "readAll", Etc.dict1("filter", "site"))
    verifyEq(g.size, 3)
    g = (Grid)call(c, "readAll", Etc.dict2("filter", "site", "opts", Etc.dict1("limit", n(2))))
    verifyEq(g.size, 2)

    // readByIds: rows correspond by index; unchecked misses are null rows
    g = (Grid)call(c, "readByIds", Etc.dict1("ids", [siteC.id, siteA.id]))
    verifyEq(g[0]->dis, "C")
    verifyEq(g[1]->dis, "A")
    g = (Grid)call(c, "readByIds", Etc.dict2("ids", [siteA.id, Ref.gen], "checked", false))
    verifyEq(g[1]["id"], null)
  }

//////////////////////////////////////////////////////////////////////////
// About
//////////////////////////////////////////////////////////////////////////

  ** about answers a typed AboutInfo instance: the spec tag rides the
  ** wire so the codec decodes each slot against its declared type
  Void doAboutTyped()
  {
    traceSection("doAboutTyped")
    about := (Dict)call(c, "about", Str:Obj?[:])
    verifyEq(about["whoami"], "charlie")
    verifyEq(about["tz"], TimeZone.cur)
    verify(about["serverTime"] is DateTime)
    verify(about["serverBootTime"] is DateTime)

    // and the instance validates against its own spec
    setupContext
    ns := proj.ns
    verifyEq(ns.validate(about, ns.spec("sys.api::AboutInfo")).hasErrs, false)
  }

//////////////////////////////////////////////////////////////////////////
// Libs
//////////////////////////////////////////////////////////////////////////

  ** The libs listing reports the namespace's composing libraries
  Void doLibsFunc()
  {
    traceSection("doLibsFunc")
    // typed decode through the codec; unqualified resolution narrows to
    // the <op> func even though hx::libs shares the name
    g := (Grid)call(c, "libs", Str:Obj?[:])
    verifyEq(g.meta->of, Ref("sys.api::LibInfo"))

    // every row validates against the LibInfo spec
    setupContext
    ns := proj.ns
    libInfo := ns.spec("sys.api::LibInfo")
    g.each |row| { verifyEq(ns.validate(row, libInfo).hasErrs, false, row->name) }

    // sys row reports the loaded version, decoded as a real Version
    row := g.find |r| { r->name == "sys" } ?: throw Err("no sys row")
    verifyEq(row->version, ns.lib("sys").version)

    // rows are sorted by name
    names := Str[,]
    g.each |r| { names.add(r->name) }
    verifyEq(names, names.dup.sort)

    // axon unqualified libs() still binds hx's runtime status func
    verifyNotNull(((Grid)eval("libs()")).col("libStatus", false))
  }

  ** The filetypes listing reports the content negotiation formats from
  ** the Filetype registry
  Void doFiletypesFunc()
  {
    traceSection("doFiletypesFunc")
    g := (Grid)call(c, "filetypes", Str:Obj?[:])
    verifyEq(g.meta->of, Ref("sys.api::FiletypeInfo"))

    // every row validates against the FiletypeInfo spec
    setupContext
    ns := proj.ns
    info := ns.spec("sys.api::FiletypeInfo")
    g.each |row| { verifyEq(ns.validate(row, info).hasErrs, false, row->name) }

    // full read/write format; the mime is the registry key verbatim
    zinc := g.find |r| { r->name == "zinc" } ?: throw Err("no zinc row")
    verifyEq(zinc->mime, "text/zinc")
    verifyEq(zinc->fileSpec, Ref("sys.files::ZincFile"))
    verifyEq(zinc->canRead, true)
    verifyEq(zinc->canWrite, true)

    // hayson's key is the bare vnd mime; version=4 is a lookup alias
    verifyEq(g.find |r| { r->name == "hayson" }->mime, "application/vnd.haystack+json")

    // write-only document format
    xml := g.find |r| { r->name == "xml" } ?: throw Err("no xml row")
    verifyEq(xml->canRead, false)
    verifyEq(xml->canWrite, true)

    // the xeto family is fully capable via the namespace codec
    verifyEq(g.find |r| { r->name == "jeto" }->canRead, true)

    // deprecated formats are listed so clients know v3 is still served
    verifyEq(g.find |r| { r->name == "jsonV3" }->mime, "application/vnd.haystack+json;version=3")

    // rows are sorted by name
    names := Str[,]
    g.each |r| { names.add(r->name) }
    verifyEq(names, names.dup.sort)
  }

//////////////////////////////////////////////////////////////////////////
// Grid Ops
//////////////////////////////////////////////////////////////////////////

  ** A grid based op receives a non-json body grid whole; the json
  ** dialect (grid as the named req arg) is covered by the shared
  ** doCommit running under this dialect's callGridOp hook
  Void doGridOps()
  {
    traceSection("doGridOps")
    db := proj.db
    verifyEq(db.readCount(Filter("gridOpTest")), 0)
    req := Etc.makeMapGrid(["commit":"add"], ["dis":"Grid Op Zinc", "gridOpTest":m])
    body := ZincWriter.gridToStr(req)
    wc := c.toWebClient(`commit`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "text/zinc"
    wc.postStr(body)
    verifyEq(wc.resCode, 200)
    resBody := wc.resStr
    wc.close
    trace(wc, body, resBody)
    verifyEq(db.readCount(Filter("gridOpTest")), 1)
  }

//////////////////////////////////////////////////////////////////////////
// Upload
//////////////////////////////////////////////////////////////////////////

  ** An op declaring a single file typed param receives the raw POST body
  ** spooled to a temp file, which the pipeline deletes after dispatch
  Void doUpload()
  {
    traceSection("doUpload")
    addLib("hx.test")

    // random bytes prove raw pass-through: no JSON parse, no charset
    // decode.  Sized to span many spool chunks (InStream.pipe copies in
    // 4096 byte chunks) with a ragged tail so the last partial chunk is
    // exercised too
    bytes := Buf.random(64 * 4096 + 17)
    digest := bytes.toDigest("SHA-256").toBase64Uri
    wc := c.toWebClient(`testUpload`)
    setVersionHeader(wc)
    wc.reqMethod = "POST"
    wc.reqHeaders["Content-Type"] = "application/octet-stream"
    wc.reqHeaders["Content-Length"] = bytes.size.toStr
    wc.writeReq
    wc.reqOut.writeBuf(bytes).close
    wc.readRes
    verifyEq(wc.resCode, 200)
    resBody := wc.resStr
    wc.close
    trace(wc, "[$bytes.size random bytes]", resBody)
    json := (Str:Obj?)JsonInStream(resBody.in).readJson

    // func received the exact bytes under the param type's fileExts
    // extension; the base name is meaningless
    verifyEq(json["size"], bytes.size.toStr)
    verifyEq(json["digest"], digest)
    verifyEq(((Str)json["name"]).endsWith(".xetolib"), true)

    // spooled temp file is deleted after dispatch; the delete runs in a
    // finally after the response is written, so poll briefly
    temp := File.os(json["path"])
    deadline := Duration.nowTicks + 1sec.ticks
    while (temp.exists && Duration.nowTicks < deadline) Actor.sleep(10ms)
    verifyFalse(temp.exists)

    // a file param must be the op's only param
    verifyReqErr(`testUploadMixed`, "", 400, "sys.api::InvalidArgsErr")

    // upload op has side effects so GET is a 405
    wc = c.toWebClient(`testUpload`)
    setVersionHeader(wc)
    wc.writeReq
    wc.readRes
    verifyResErr(wc, null, 405, "sys.api::MethodNotAllowedErr")
  }

//////////////////////////////////////////////////////////////////////////
// Content Negotiation
//////////////////////////////////////////////////////////////////////////

  ** The negotiation exchange is identical to version 4: Content-Type
  ** selects the reader, Accept or ?xeto-filetype selects the writer.
  ** Only application/json binds differently - the xeto codec here, the
  ** haystack codec in v4 - which the other Api5Test requests cover.
  Void doNegotiation()
  {
    traceSection("doNegotiation")
    // zinc request body: the first row cells are the named args, and
    // with no Accept header the response defaults to xeto JSON
    body := ZincWriter.gridToStr(Etc.makeMapGrid(null, ["id":siteA.id]))
    wc := c.toWebClient(`readById`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "text/zinc"
    wc.postStr(body)
    verifyEq(wc.resCode, 200)
    verifyEq(wc.resHeaders["Content-Type"], "application/json")
    resBody := wc.resStr
    wc.close
    trace(wc, body, resBody)
    rec := (Str:Obj?)JsonInStream(resBody.in).readJson
    verifyEq(rec["dis"], "A")

    // Accept selects a zinc response for a json request
    body = """{"id":"$siteA.id.id"}"""
    wc = c.toWebClient(`readById`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/json"
    wc.reqHeaders["Accept"] = "text/zinc"
    wc.postStr(body)
    verifyEq(wc.resCode, 200)
    verifyEq(wc.resHeaders["Xeto-Version"], "5")
    verify(wc.resHeaders["Content-Type"].startsWith("text/zinc"))
    resBody = wc.resStr
    wc.close
    trace(wc, body, resBody)
    grid := ZincReader(resBody.in).readGrid
    verifyEq(grid.first->dis, "A")

    // hayson under v5 via its explicit vnd mime, both directions; bare
    // application/json binds to jeto in this dialect so hayson must be
    // named explicitly
    wc = c.toWebClient(`readById`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/vnd.haystack+json"
    wc.reqHeaders["Accept"] = "application/vnd.haystack+json"
    buf := StrBuf()
    HaysonWriter(buf.out).writeGrid(Etc.makeMapGrid(null, ["id":siteA.id]))
    wc.postStr(buf.toStr)
    verifyEq(wc.resCode, 200)
    resBody = wc.resStr
    wc.close
    trace(wc, buf.toStr, resBody)
    grid = HaysonReader(resBody.in).readGrid
    verifyEq(grid.first->dis, "A")

    // hayson v3 dialect selected by the version mime param
    wc = c.toWebClient(`readById`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/vnd.haystack+json;version=3"
    wc.reqHeaders["Accept"] = "application/vnd.haystack+json;version=3"
    buf = StrBuf()
    HaysonWriter(buf.out, Etc.dict1("v3", m)).writeGrid(Etc.makeMapGrid(null, ["id":siteA.id]))
    wc.postStr(buf.toStr)
    verifyEq(wc.resCode, 200)
    resBody = wc.resStr
    wc.close
    trace(wc, buf.toStr, resBody)
    grid = HaysonReader(resBody.in, Etc.dict1("v3", m)).readGrid
    verifyEq(grid.first->dis, "A")

    // xeto and jeto behave exactly like application/json in this
    // dialect: one object of named args in, the bare result value out
    body = "{id: @$siteA.id.id, checked: Bool \"true\"}"
    wc = c.toWebClient(`readById`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "text/xeto"
    wc.reqHeaders["Accept"] = "text/xeto"
    wc.postStr(body)
    verifyEq(wc.resCode, 200)
    verify(wc.resHeaders["Content-Type"].startsWith("text/xeto"))
    resBody = wc.resStr
    wc.close
    trace(wc, body, resBody)
    resDict := (Dict)proj.ns.io.readXeto(resBody, Etc.dict1("externRefs", m))
    verifyEq(resDict->dis, "A")

    body = """{"id":"$siteA.id.id"}"""
    wc = c.toWebClient(`readById`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "text/jeto"
    wc.reqHeaders["Accept"] = "text/jeto"
    wc.postStr(body)
    verifyEq(wc.resCode, 200)
    verify(wc.resHeaders["Content-Type"].startsWith("application/json"))  // jeto is served as plain json
    resBody = wc.resStr
    wc.close
    trace(wc, body, resBody)
    resDict = (Dict)proj.ns.io.readJeto(resBody.in)
    verifyEq(resDict->dis, "A")

    // box modes: the Accept box param selects the JSON boxing.  none is
    // the wire the JSON schemas describe, so the Number comes back in
    // its plain form rather than the auto box naming its spec
    body = """{"expr":"1kW"}"""
    wc = c.toWebClient(`eval`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/json"
    wc.reqHeaders["Accept"] = "application/json;box=none"
    wc.postStr(body)
    verifyEq(wc.resCode, 200)
    resBody = wc.resStr
    wc.close
    trace(wc, body, resBody)
    verifyEq(JsonInStream(resBody.in).readJson, "1kW")

    // the default is auto: the Number boxes so the untyped position
    // survives the trip
    wc = c.toWebClient(`eval`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/json"
    wc.postStr(body)
    verifyEq(wc.resCode, 200)
    resBody = wc.resStr
    wc.close
    trace(wc, body, resBody)
    boxed := (Str:Obj?)JsonInStream(resBody.in).readJson
    verifyEq(boxed["spec"], "sys::Number")
    verifyEq(boxed["val"], "1kW")

    // box=all boxes even a scalar whose plain form would decode back
    body = """{"expr":"true"}"""
    wc = c.toWebClient(`eval`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/json"
    wc.reqHeaders["Accept"] = "application/json;box=all"
    wc.postStr(body)
    verifyEq(wc.resCode, 200)
    resBody = wc.resStr
    wc.close
    trace(wc, body, resBody)
    verify(resBody.contains("sys::Bool"))
    verifyEq(proj.ns.io.readJeto(resBody.in), true)

    // the box param composes with the jeto mime too
    body = """{"expr":"1kW"}"""
    wc = c.toWebClient(`eval`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/json"
    wc.reqHeaders["Accept"] = "text/jeto;box=none"
    wc.postStr(body)
    verifyEq(wc.resCode, 200)
    resBody = wc.resStr
    wc.close
    trace(wc, body, resBody)
    verifyEq(JsonInStream(resBody.in).readJson, "1kW")

    // an unrecognized box token is a 406 so a client never silently
    // gets the wrong wire
    wc = c.toWebClient(`eval`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/json"
    wc.reqHeaders["Accept"] = "application/json;box=bogus"
    wc.postStr(body)
    verifyResErr(wc, body, 406, "sys.api::NotAcceptableErr")

    // an opGrid op through jeto named args: the flag is inert on this
    // path and the grid rides as the "req" member
    body = proj.ns.io.writeJetoToStr(Etc.dict1("req", Etc.makeEmptyGrid))
    wc = c.toWebClient(`nav`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "text/jeto"
    wc.reqHeaders["Accept"] = "text/jeto"
    wc.postStr(body)
    verifyEq(wc.resCode, 200)
    resBody = wc.resStr
    wc.close
    trace(wc, body, resBody)
    verify(proj.ns.io.readJeto(resBody.in) is Grid)

    // ?xeto-filetype=xeto GET answers the bare value
    wc = c.toWebClient(`readById?id=$siteA.id.id&xeto-filetype=xeto`)
    setVersionHeader(wc)
    wc.writeReq
    wc.readRes
    verifyEq(wc.resCode, 200)
    resBody = wc.resStr
    wc.close
    trace(wc, null, resBody)
    resDict = (Dict)proj.ns.io.readXeto(resBody, Etc.dict1("externRefs", m))
    verifyEq(resDict->dis, "A")

    // ?xeto-filetype query override selects the writer for easy testing
    wc = c.toWebClient(`readById?id=$siteA.id.id&xeto-filetype=trio`)
    setVersionHeader(wc)
    wc.writeReq
    wc.readRes
    verifyEq(wc.resCode, 200)
    resBody = wc.resStr
    wc.close
    trace(wc, null, resBody)
    grid = TrioReader(resBody.in).readGrid
    verifyEq(grid.first->dis, "A")

    // a POST with no Content-Type is a 415, same as v4
    wc = c.toWebClient(`readById`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Length"] = "2"
    wc.reqMethod = "POST"
    wc.writeReq
    wc.reqOut.print("{}").close
    wc.readRes
    verifyResErr(wc, "{}", 415, "sys.api::UnsupportedMediaTypeErr")

    // a Content-Type with no reader is a 415
    wc = c.toWebClient(`readById`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/octet-stream"
    wc.postStr("""{"id":"x"}""")
    verifyResErr(wc, """{"id":"x"}""", 415, "sys.api::UnsupportedMediaTypeErr")

    // an Accept with no writer is a 406
    wc = c.toWebClient(`readById`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/json"
    wc.reqHeaders["Accept"] = "image/png"
    wc.postStr("""{"id":"$siteA.id.id"}""")
    verifyResErr(wc, null, 406, "sys.api::NotAcceptableErr")
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void verifyCall(Client c, Str op, Obj args, Obj? expect)
  {
    actual := call(c, op, args)
    verifyEq(actual, expect)
  }

  ** POST the args as a JSON object and decode the JSON result.  Both ends
  ** use the xeto codec, which is the one the dispatch itself uses, so the
  ** args are encoded exactly as a real v5 client would send them.
  Obj? call(Client c, Str op, Obj args)
  {
    ns := proj.ns
    req := ns.io.writeJetoToStr(Etc.makeDict(args))

    wc := c.toWebClient(op.toUri)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/json"
    wc.postStr(req)
    res := wc.resStr
    wc.close
    trace(wc, req, res)

    if (wc.resCode != 200) throw toCallErr(res, wc.resCode)
    return ns.io.readJeto(res.in)
  }

  ** Map a v5 JSON error envelope to CallErr so shared assertions catch
  ** the same err type both dialects raise
  private static CallErr toCallErr(Str res, Int code)
  {
    [Str:Obj?]? json := null
    try json = JsonInStream(res.in).readJson as Str:Obj?
    catch (Err e) {}
    if (json == null || json["dis"] == null) json = Str:Obj?["dis":"Bad HTTP response $code"]
    return CallErr.makeMeta(Etc.makeDict(json))
  }
}

