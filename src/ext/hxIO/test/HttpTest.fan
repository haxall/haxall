//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Mar 2026  Trevor Adelman  Creation
//

using web
using haystack
using hx
using xeto

**
** HttpTest verifies ioHttp round-trip against a local test server
**
class HttpTest : HxTest
{
  Service? wisp
  Int port := 0

  @HxTestProj
  Void test()
  {
    addLib("hx.io")
    startServer
    try
    {
      // create test file for file body tests
      eval("""ioWriteStr("file body content", `io/http-test.txt`)""")

      // response codes
      verifyHttp(`/echo`, "GET", null, null, null, 200)
      verifyHttp(`/bad`,  "GET", null, null, null, 404)

      // str body with Content-Type
      verifyHttp(`/echo`, "POST",
        Str:Str["Content-Type":"text/plain"],
        "hello world", null, 200)

      // str body without Content-Type (defaults to application/octet-stream)
      verifyHttp(`/echo`, "POST", null,
        "no content type", null, 200)

      // headers present but no Content-Type
      verifyHttp(`/echo`, "POST",
        Str:Str["X-Custom":"foo"],
        "custom header", null, 200)

      // buf body with binary content
      verifyHttp(`/echo`, "POST",
        Str:Str["Content-Type":"application/octet-stream"],
        Buf().write(0xCA).write(0xFE).write(0xBA).write(0xBE).flip,
        null, 200)

      // file body
      verifyHttp(`/echo`, "POST",
        Str:Str["Content-Type":"text/plain"],
        `io/http-test.txt`, null, 200)

      // response body via ioReadJson
      verifyHttp(`/json`, "GET", null, null, "json", 200)

      // response body via ioReadStr
      verifyHttp(`/echo`, "GET", null, null, "str", 200)
    }
    finally stopServer
  }

//////////////////////////////////////////////////////////////////////////
// Server
//////////////////////////////////////////////////////////////////////////

  Void startServer()
  {
    wisp = Slot.findMethod("wisp::WispService.testSetup").call(EchoMod())
    wisp.start
    port = wisp->httpPort
  }

  Void stopServer()
  {
    wisp.stop
  }

//////////////////////////////////////////////////////////////////////////
// Verify
//////////////////////////////////////////////////////////////////////////

  Void verifyHttp(Uri path, Str method, [Str:Str]? headers, Obj? body, Str? resReader, Int code := 200)
  {
    uri := "http://localhost:$port" + path.toStr
    hExpr := toHeadersExpr(headers)
    bExpr := toBodyExpr(body)

    // choose callback based on response reader
    cb := "(code, headers, body) => {code: code, body: ioReadStr(body)}"
    if (resReader == "json")
      cb = "(code, headers, body) => {code: code, json: ioReadJson(body)}"

    axon := """ioHttp(`$uri`, "$method", $hExpr, $bExpr, $cb)"""

    Dict res := eval(axon)
    verifyEq(res["code"], n(code))

    // verify method echoed back on 200
    if (code == 200 && res.has("body"))
      verify(res["body"].toStr.contains("method=$method"))

    // verify JSON response parsed correctly
    if (resReader == "json")
    {
      json := res["json"] as Dict
      verifyEq(json["key"], "value")
      verifyEq(json["num"], n(42))
    }
  }

  private Str toHeadersExpr([Str:Str]? headers)
  {
    if (headers == null) return "null"
    pairs := StrBuf()
    headers.each |v, k|
    {
      if (pairs.size > 0) pairs.add(", ")
      pairs.add("\"$k\": \"$v\"")
    }
    return "{$pairs}"
  }

  private Str toBodyExpr(Obj? body)
  {
    if (body == null) return "null"
    if (body is Str)  return body.toStr.toCode
    if (body is Uri)  return ((Uri)body).toCode
    if (body is Buf)
    {
      b64 := ((Buf)body).toBase64
      return "ioFromBase64(\"$b64\")"
    }
    throw ArgErr("Unsupported body type: $body.typeof")
  }
}

**************************************************************************
** EchoMod
**************************************************************************

**
** Simple WebMod that echoes request details back in the response
**
internal const class EchoMod : WebMod
{
  override Void onService()
  {
    path := req.modRel.path.getSafe(0) ?: "echo"

    // 404
    if (path == "bad")
    {
      res.statusCode = 404
      res.headers["Content-Type"] = "text/plain"
      res.out.print("not found").close
      return
    }

    // JSON response for ioReadJson testing
    if (path == "json")
    {
      res.headers["Content-Type"] = "application/json"
      res.out.print(Str<|{"key":"value","num":42}|>).close
      return
    }

    // echo request details
    ct := req.headers["Content-Type"]
    cl := req.headers["Content-Length"]
    body := ""
    if (cl != null)
    {
      if (ct != null && ct.startsWith("text/"))
        body = req.in.readAllStr
      else
      {
        buf := Buf()
        req.in.pipe(buf.out)
        body = "bytes:$buf.size"
      }
    }

    res.headers["Content-Type"] = "text/plain"
    res.headers["X-Echo-Test"] = "active"
    out := res.out
    out.print("method=$req.method\n")
    if (ct != null) out.print("content-type=$ct\n")
    if (cl != null) out.print("content-length=$cl\n")
    if (body.size > 0) out.print("body=$body\n")
    out.close
  }
}
