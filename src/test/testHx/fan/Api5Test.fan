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
    doWriteRes
    doEval
    doAboutTyped
    doUpload
    doNegotiation
    cleanup

    // TODO: doCommon needs a v5 shape for the ops which still take a v4
    // style "req: Grid" arg; eval is the first one modeled with real params
  }

//////////////////////////////////////////////////////////////////////////
// Write Response
//////////////////////////////////////////////////////////////////////////

  ** The response half of the dispatch is implemented ahead of the request
  ** half, so exercise it with ops which need no args decoded.  Version 5
  ** answers clean JSON with no grid envelope.
  Void doWriteRes()
  {
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
  }

  ** POST an op and decode the JSON response, verifying the version 5
  ** response envelope along the way
  private Obj? postJson(Uri op, Str body := "")
  {
    wc := c.toWebClient(op)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/json"
    wc.postStr(body)
    verifyEq(wc.resCode, 200)
    verifyEq(wc.resHeaders["Content-Type"], "application/json")
    verifyEq(wc.resHeaders["Xeto-Version"], "5")
    res := JsonInStream(wc.resStr.in).readJson
    wc.close
    return res
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
    res := JsonInStream(wc.resStr.in).readJson
    wc.close
    return res
  }

  ** Verify a bad request reports the given status and ApiErr spec
  private Void verifyReqErr(Uri op, Str body, Int code, Str spec)
  {
    wc := c.toWebClient(op)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/json"
    wc.postStr(body)
    verifyEq(wc.resCode, code)
    json := (Str:Obj?)JsonInStream(wc.resStr.in).readJson
    wc.close
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

//////////////////////////////////////////////////////////////////////////
// Eval
//////////////////////////////////////////////////////////////////////////

  Void doEval()
  {
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
// About
//////////////////////////////////////////////////////////////////////////

  ** about answers a typed AboutInfo instance: the spec tag rides the
  ** wire so the codec decodes each slot against its declared type
  Void doAboutTyped()
  {
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
// Upload
//////////////////////////////////////////////////////////////////////////

  ** An op declaring a single file typed param receives the raw POST body
  ** spooled to a temp file, which the pipeline deletes after dispatch
  Void doUpload()
  {
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
    json := (Str:Obj?)JsonInStream(wc.resStr.in).readJson
    wc.close

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
    verifyEq(wc.resCode, 405)
    wc.close
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
    // zinc request body: the first row cells are the named args, and
    // with no Accept header the response defaults to xeto JSON
    wc := c.toWebClient(`readById`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "text/zinc"
    wc.postStr(ZincWriter.gridToStr(Etc.makeMapGrid(null, ["id":siteA.id])))
    verifyEq(wc.resCode, 200)
    verifyEq(wc.resHeaders["Content-Type"], "application/json")
    rec := (Str:Obj?)JsonInStream(wc.resStr.in).readJson
    wc.close
    verifyEq(rec["dis"], "A")

    // Accept selects a zinc response for a json request
    wc = c.toWebClient(`readById`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/json"
    wc.reqHeaders["Accept"] = "text/zinc"
    wc.postStr("""{"id":"$siteA.id.id"}""")
    verifyEq(wc.resCode, 200)
    verifyEq(wc.resHeaders["Xeto-Version"], "5")
    verify(wc.resHeaders["Content-Type"].startsWith("text/zinc"))
    grid := ZincReader(wc.resStr.in).readGrid
    wc.close
    verifyEq(grid.first->dis, "A")

    // ?xeto-filetype query override selects the writer for easy testing
    wc = c.toWebClient(`readById?id=$siteA.id.id&xeto-filetype=trio`)
    setVersionHeader(wc)
    wc.writeReq
    wc.readRes
    verifyEq(wc.resCode, 200)
    grid = TrioReader(wc.resStr.in).readGrid
    wc.close
    verifyEq(grid.first->dis, "A")

    // a POST with no Content-Type is a 415, same as v4
    wc = c.toWebClient(`readById`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Length"] = "2"
    wc.reqMethod = "POST"
    wc.writeReq
    wc.reqOut.print("{}").close
    wc.readRes
    verifyEq(wc.resCode, 415)
    wc.close

    // a Content-Type with no reader is a 415
    wc = c.toWebClient(`readById`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/octet-stream"
    wc.postStr("""{"id":"x"}""")
    verifyEq(wc.resCode, 415)
    wc.close

    // an Accept with no writer is a 406
    wc = c.toWebClient(`readById`)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/json"
    wc.reqHeaders["Accept"] = "image/png"
    wc.postStr("""{"id":"$siteA.id.id"}""")
    verifyEq(wc.resCode, 406)
    wc.close
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
    if (debug) { echo(">>>> $op"); echo(req) }

    wc := c.toWebClient(op.toUri)
    setVersionHeader(wc)
    wc.reqHeaders["Content-Type"] = "application/json"
    wc.postStr(req)
    res := wc.resStr
    wc.close
    if (debug) { echo("<<<< $wc.resCode"); echo(res) }

    if (wc.resCode != 200) throw IOErr("Bad HTTP response $wc.resCode $wc.resPhrase")
    return ns.io.readJeto(res.in)
  }

  const Bool debug := false
}

