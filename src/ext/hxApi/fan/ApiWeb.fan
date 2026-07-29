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
const class ApiWeb : ExtWeb, WebOpUtil
{
  new make(ApiExt ext) : super(ext) {}

  virtual Sys sys() { ext.sys }

  override ApiExt ext() { super.ext }

  virtual DefNamespace defs() { ext.rt.defs }

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
    req := this.req
    res := this.res
    try
    {
      // path must be /api/{projName}/...
      path := req.modRel.path
      if (path.size < 2) return res.sendErr(404)
      projName := path[0]

      // lookup project
      Runtime? rt := sys.proj.get(projName, false)

      // allow cluster nodeId to be used as projName for sys
      if (rt == null)
      {
        nodeId := sys.cluster(false)?.nodeId
        if (nodeId != null && nodeId.segs.last.body == projName)
          rt = sys
      }

      // no joy resolving runtime, return 404
      if (rt == null) return res.sendErr(404, "Proj not found")

      // handle web socket requests
      if (req.headers["Upgrade"] == "websocket")
      {
        if (path.size != 1) return res.sendErr(404)
        //return onWebSocket(req, res, proj)
        ext.log.warn("onWebSocket upgrade [$rt]")
        return res.sendErr(426)
      }

      // authenticate user
      cx := sys.user.authenticate(req, res, rt)
      if (cx == null) return
      cx.timeout = rt.meta.evalTimeout

      // anything else must be /api/{projName}/{opName}/...
      if (path.size < 2) return res.sendErr(404)
      opName := path[1]
      req.modBase = req.uri[0..2].plusSlash

      // if opName has dot then its Haxall 4.x xeto style
      if (opName.contains("."))
      {
        return res.sendErr(406, "New API design not supported")
        //HxApiReq.service(req, res, opName, cx)
        //return
      }

      // otherwise Haxall 3.x legacy style: a registered op class takes
      // precedence, else bind to the func of that name
      typeName := cx.defs.def("op:$opName", false)?.get("typeName") as Str
      op := typeName != null ? HxApiOp.find(typeName) : (HxApiOp?)HxFuncOp.findByOpName(opName, cx)
      if (op == null) return res.sendErr(404)

      // route to op for processing
      op.onService(req, res, cx)
    }
    catch (Err e)
    {
      if (res.isCommitted)
        e.trace
      else
        writeRes(toErrGrid(e))
    }
    finally
    {
      Actor.locals.remove(ActorContext.actorLocalsKey)
    }
  }

  ** Map mod rel path to an op name or return null for 404
  ** We allow the following paths:
  **   - /api/op
  **   - /api/{cluster-node-id}/op   (to support tunneling)
  private Str? pathToOpName(Str[] path)
  {
    if (path.size == 1) return path[0]
    if (path.size == 2)
    {
      cluster := ext.sys.cluster(false)
      if (cluster != null && path[0] == cluster.nodeId.segs[0].body)
        return path[1]
    }
    return null
  }

  ** Read Haystack op request grid
  private Grid? readReq()
  {
    doReadReq(req, res)
  }

  ** Writer Haystack op response grid
  private Void writeRes(Obj? result)
  {
    if (res.isCommitted) return
    doWriteRes(req, res, Etc.toGrid(result))
  }

  ** Write error response
  virtual Grid toErrGrid(Err err, Obj? meta := null)
  {
    if (ext.settings.has("disableErrTrace"))
    {
      meta = Etc.makeDict(meta)
      meta = Etc.dictSet(meta, "errTrace", "${err}\n  Trace disabled")
    }
    return Etc.makeErrGrid(err, meta)
  }
}
