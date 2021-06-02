//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Jun 2021  Brian Frank  Creation
//

using dom
using haystack

**
** HTTP API client session
**
@Js
const class Session
{
  ** Construct with endpoint uri
  new make()
  {
    this.uri       = Env.cur.vars.getChecked("hxShell.api").toUri
    this.attestKey = Env.cur.vars.getChecked("hxShell.attestKey")
    this.user      = ZincReader(Env.cur.vars.getChecked("hxShell.user").in).readVal
  }

  ** Endpoint URI which is typically "/api/"
  const Uri uri

  ** Attestation session key used as secondary verification of cookie key
  const Str attestKey

  ** User record
  const Dict user

  ** Convenience for `call` to the eval op
  ApiCallFuture eval(Str expr)
  {
    call("eval", Etc.makeDictGrid(null, Etc.makeDict1("expr", expr)))
  }

  ** Make a Haystack API call
  ApiCallFuture call(Str op, Grid req)
  {
    // create future instance
    future := ApiCallFuture()

    // create req instance
    http := prepare(op)

    // post to server
    http.post(ZincWriter.gridToStr(req)) |res|
    {
      // attempt to parse response, or create error grid
      Grid? resGrid
      try
      {
        if (res.status == 0) throw IOErr("Could not connect to server")
        if (res.status != 200) throw IOErr("Invalid HTTP response: $res.status")
        resGrid = ZincReader(res.content.in).readGrid
      }
      catch (Err e)
      {
        resGrid = Etc.makeErrGrid(e)
      }

      // resolve future
      future.complete(resGrid)
    }

    return future
  }

  ** Prepare HTTP request with standard headers
  HttpReq prepare(Str op)
  {
    HttpReq
    {
      it.uri = this.uri + `${op}`
      it.headers["Content-Type"] = "text/zinc; charset=utf-8"
      it.headers["X-Attest-Key"] = attestKey
    }
  }
}

**************************************************************************
** ApiCallFuture
**************************************************************************

** ApiCallFuture is used to handle ok/error callbacks
@Js
class ApiCallFuture
{
  ** Complete request
 internal Void complete(Grid res)
  {
    if (res.meta.has("err"))
      cbErr?.call(res)
    else
      cbOk?.call(res)
  }

  ** Callback when request completes successfully
  This onOk(|Grid| f) { this.cbOk = f; return this }

  ** Callback when request completes with an error
  This onErr(|Grid| f) { this.cbErr = f; return this }

  private Func? cbOk
  private Func? cbErr := |Grid g| { g.dump }
}