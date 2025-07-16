//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2025  Brian Frank  Creation
//

using web
using xeto
using haystack

**
** HxApi manages Haxall 4.x style HTTP requests.  APIs are declared
** as Xeto globals that subtype 'sys.api::Api'.  They must be mapped
** a static method annotated with this facet and registered with the
** runtime using the "xeto.api" indexed prop.
**
@NoDoc
facet class HxApi {}

**
** IonApi annotates a method available for ion::UiApi calls.  It must
** be a static method that takes a Dict request and Context.  It is
** registered via the "ion.api" indexed prop.
**
@NoDoc
facet class IonApi {}

**************************************************************************
** HxApiReq
**************************************************************************

@NoDoc
class HxApiReq
{
  ** Service an API endpoint call
  static Void service(WebReq req, WebRes res, Str op, Context cx)
  {
throw Err("TODO")
/*
    // resolve to api function
    spec := cx.ns.api(op, false)
    if (spec == null) return res.sendErr(404)

    // resolve sped to its implementation method
    method := spec.func.api(false) as Method
    if (method == null) return res.sendErr(404)

    // only support POST
    if (req.method != "POST") return res.sendErr(405)

    // route to method
    result := null
    try
    {
      // parse args (TODO, just temp using hayson)
      args := JsonReader(req.in).readVal
      if (args isnot Dict) return res.sendErr(400, "Cannot parse req args")

      // result
      result = method.call(make(req, res, spec, args, cx))

      // encode
      res.headers["Content-Type"] = "application/json"
      JsonWriter(res.out).writeVal(result)
    }
    catch (Err e)
    {
      res.headers["Content-Type"] = "application/json"
      JsonWriter(res.out).writeVal(Etc.dict2("status", "error", "msg", e.toStr))
    }
*/
  }

  ** Constructor
  protected new make(WebReq req, WebRes res, Spec spec, Dict args, Context cx)
  {
    this.reqRef  = req
    this.resRef  = res
    this.specRef = spec
    this.argsRef = args
    this.cxRef   = cx
  }

  ** Web request
  WebReq req() { reqRef }

  ** Web response
  WebRes res() { resRef }

  ** Spec for the api function
  Spec spec() { specRef }

  ** Arguments for app by name
  Dict args() { argsRef }

  ** Context
  Context context() { cxRef }

  private WebReq reqRef
  private WebRes resRef
  private const Spec specRef
  private const Dict argsRef
  private Context cxRef
}

