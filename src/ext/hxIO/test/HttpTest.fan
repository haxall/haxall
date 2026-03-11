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
      verifyGet
      verifyPost
      verifyPut
      verifyDelete
      verifyResHeaders
      verify404
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
// Tests
//////////////////////////////////////////////////////////////////////////

  Void verifyGet()
  {
    Dict res := eval(
      """ioHttp(`http://localhost:$port/echo`, "GET", null, null,
           (code, headers, body) => {code: code, body: ioReadStr(body)})""")
    verifyEq(res["code"], n(200))
    verifyEq(res["body"].toStr.contains("method=GET"), true)
  }

  Void verifyPost()
  {
    Dict res := eval(
      """ioHttp(`http://localhost:$port/echo`, "POST",
           {"Content-Type":"text/plain"}, "hello world",
           (code, headers, body) => {code: code, body: ioReadStr(body)})""")
    verifyEq(res["code"], n(200))
    verifyEq(res["body"].toStr.contains("method=POST"), true)
    verifyEq(res["body"].toStr.contains("body=hello world"), true)
  }

  Void verifyPut()
  {
    Dict res := eval(
      """ioHttp(`http://localhost:$port/echo`, "PUT",
           {"Content-Type":"text/plain"}, "put data",
           (code, headers, body) => {code: code, body: ioReadStr(body)})""")
    verifyEq(res["code"], n(200))
    verifyEq(res["body"].toStr.contains("method=PUT"), true)
    verifyEq(res["body"].toStr.contains("body=put data"), true)
  }

  Void verifyDelete()
  {
    Dict res := eval(
      """ioHttp(`http://localhost:$port/echo`, "DELETE", null, null,
           (code, headers, body) => {code: code, body: ioReadStr(body)})""")
    verifyEq(res["code"], n(200))
    verifyEq(res["body"].toStr.contains("method=DELETE"), true)
  }

  Void verifyResHeaders()
  {
    Dict res := eval(
      """ioHttp(`http://localhost:$port/echo`, "GET", null, null,
           (code, headers, body) => headers)""")
    verifyEq(res["X-Echo-Test"], "active")
  }

  Void verify404()
  {
    Dict res := eval(
      """ioHttp(`http://localhost:$port/notfound`, "GET", null, null,
           (code, headers, body) => {code: code})""")
    verifyEq(res["code"], n(404))
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
    if (req.modRel.path.getSafe(0) == "notfound")
    {
      res.statusCode = 404
      res.headers["Content-Type"] = "text/plain"
      res.out.print("not found").close
      return
    }

    body := ""
    if (req.headers["Content-Type"] != null)
      body = req.in.readAllStr

    res.headers["Content-Type"] = "text/plain"
    res.headers["X-Echo-Test"] = "active"
    out := res.out
    out.print("method=$req.method\n")
    out.print("body=$body\n")
    out.close
  }
}
