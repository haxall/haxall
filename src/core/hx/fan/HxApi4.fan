//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2025  Brian Frank  Creation
//

using web
using xeto

**
** HxApi manages Haxall 4.x style HTTP requests.  APIs are declared
** as Xeto globals that subtype 'sys.api::Api'.  They must be mapped
** a static method annotated with this facet and registered with the
** runtime using the "xeto.api" indexed prop.
**
@NoDoc
facet class HxApi {}

**************************************************************************
** HxApiReq
**************************************************************************

@NoDoc
class HxApiReq
{
  ** Service an API endpoint call
  static Void service(WebReq req, WebRes res, Str op, HxContext cx)
  {
    // resolve to api function
    spec := cx.xeto.api(op, false)
    if (spec == null) return res.sendErr(404)

    // resolve sped to its implementation method
    method := spec.func.api(false) as Method
    if (method == null) return res.sendErr(404)

    // route to method
    result := null
    try
    {
      result = method.call(make(req, res, spec, cx))
    }
    catch (Err e)
    {
      result = e
    }

    res.headers["Content-Type"] = "application/json"
    res.out.print(result)
  }

  ** Constructor
  protected new make(WebReq req, WebRes res, Spec spec, HxContext cx)
  {
    this.reqRef  = req
    this.resRef  = res
    this.specRef = spec
    this.cxRef   = cx
  }

  ** Web request
  WebReq req() { reqRef }

  ** Web response
  WebRes res() { resRef }

  ** Spec for the api function
  Spec spec() { specRef }

  ** Context
  HxContext context() { cxRef }

  private WebReq reqRef
  private WebRes resRef
  private Spec specRef
  private HxContext cxRef
}

