//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using concurrent
using web
using haystack
using hx

**
** HTTP API web service handling
**
const class ApiWeb : ExtWeb, WebOpUtil
{
  new make(ApiExt ext) : super(ext) {}

  override ApiExt ext() { super.ext }

  override DefNamespace defs() { ext.proj.defs }

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
      rt := sys.proj.get(projName, false)
      if (rt == null) return res.sendErr(404, "Proj not found")

      // handle web socket requests
      if (req.headers["Upgrade"] == "websocket")
      {
        if (path.size != 1) return res.sendErr(404)
        //return onWebSocket(req, res, proj)
        ext.log.warn("onWebSocket upgrade [$proj]")
        return res.sendErr(426)
      }

      // authenticate user
      session := sys.user.authenticate(req, res)
      if (session == null) return
      cx := rt.newContextSession(session)
      cx.timeout = Context.timeoutDef
      Actor.locals[Context.actorLocalsKey] = cx

      // anything else must be /api/{projName}/{opName}/...
      if (path.size < 2) return res.sendErr(404)
      opName := path[1]

      // if opName has dot then its Haxall 4.x xeto style
      if (opName.contains("."))
      {
        return res.sendErr(406, "New API design not supported")
        //HxApiReq.service(req, res, opName, cx)
        //return
      }

      // otherwise map to op def for Haxall 3.x legacy style
      opDef := cx.defs.def("op:$opName", false)
      if (opDef == null) return res.sendErr(404)

      // instantiate subclass of HxApiOp
      Actor.locals["hxApiOp.spi"] = HxApiOpSpiImpl(defs, opDef)
      typeName := opDef["typeName"] as Str ?: throw Err("Op missing typeName: $opName")
      op := (HxApiOp)Type.find(typeName).make

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
      Actor.locals.remove("hxApiOp.spi")
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
  private Grid toErrGrid(Err err, Obj? meta := null)
  {
    if (ext.settings.has("disableErrTrace"))
    {
      meta = Etc.makeDict(meta)
      meta = Etc.dictSet(meta, "errTrace", "${err}\n  Trace disabled")
    }
    return Etc.makeErrGrid(err, meta)
  }
}

**************************************************************************
** HxApiOpSpiImpl
**************************************************************************

internal const class HxApiOpSpiImpl : WebOpUtil, HxApiOpSpi
{
  new make(DefNamespace defs, Def def)
  {
    this.defs = defs
    this.name = def.name
    this.def  = def
  }

  override Grid? readReq(HxApiOp op, WebReq req, WebRes res)
  {
    // GET requests can only call ops with no side effects
    if (req.isGet && !op.isGetAllowed)
    {
      res.sendErr(405, "GET not allowed for op '$name'")
      return null
    }

    // WebOpUtil handling
    return doReadReq(req, res)
  }

  override Void writeRes(HxApiOp op, WebReq req, WebRes res, Grid grid)
  {
    // WebOpUtil handling
    doWriteRes(req, res, grid)
  }

  override const DefNamespace defs
  override const Str name
  override const Def def
}

