//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using concurrent
using web
using xeto
using haystack
using hx

**
** HTTP API web service handling
**
const class ApiWeb : ExtWeb
{
  new make(ApiExt ext) : super(ext) {}

  override ApiExt ext() { super.ext }

  override const Str[] wellKnownRoutes := ["health"]

  override Void onWellKnown()
  {
    ** Service simple health check
    if (req.isGet && req.modRel.pathStr == "health")
    {
      res.statusCode = 200
      res.headers["Content-Type"] = "application/json"
      res.headers["Cache-Control"] = "no-cache, no-store"
      return res.out.printLine(Str<|{"status":"ok"}|>).close
    }
    return super.onWellKnown
  }

  override Void onService()
  {
    ((ApiPipeline)ext.pipelineType.make([ext, req, res])).service
  }
}

