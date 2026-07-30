//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jul 2026  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack
using axon
using hx
using web

**
** ApiPipeline handles the entire lifecycle of an API op call
**
class ApiPipeline
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Construct
  new make(ApiExt ext, WebReq req, WebRes res)
  {
    this.sys    = ext.sys
    this.ext    = ext
    this.req    = req
    this.res    = res
    this.path   = req.modRel.path
    this.rtName = path.getSafe(0)
    this.opName = path.getSafe(1)
  }

//////////////////////////////////////////////////////////////////////////
// Service
//////////////////////////////////////////////////////////////////////////

  ** Run the entire pipeline for the operation
  Void service()
  {
    try
    {
      resolveRuntime
      upgrade
      if (!authenticate) return
      resolveVersion
      resolveOpFunc
      dispatch
    }
    catch (ApiErr e)
    {
      writeErr(e.code, e.msg, e.cause)
    }
    catch (EvalErr e)
    {
      e = e.cause ?: e
      writeErr(500, e.msg, e)
    }
    catch (PermissionErr e)
    {
      writeErr(403, e.msg, e.cause)
    }
    catch (Err e)
    {
      writeErr(500, "Internal error: $e.msg", e)
    }
    finally
    {
      Actor.locals.remove(ActorContext.actorLocalsKey)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Steps
//////////////////////////////////////////////////////////////////////////

  ** Resolve /api/{rt name} to the runtime
  private Void resolveRuntime()
  {
    // if path too short
    if (rtName == null) throw err(404, "Invalid path")

    // lookup project
    rt = sys.proj.get(rtName, false)
    if (rt != null) return

    // allow cluster nodeId to be used as projName for sys
    nodeId := sys.cluster(false)?.nodeId
    if (nodeId != null && nodeId.segs.last.body == rtName)
    {
      rt = sys
      return
    }

    // 404 no joy resolving runtime
    throw err(404, "Proj not found")
  }

  ** Check for websocket upgrade before authentication (not implemented yet)
  private Void upgrade()
  {
    // check for upgrade to websocket
    if (req.headers["Upgrade"] != "websocket") return

    // not implemented yet
    ext.log.warn("onWebSocket upgrade [$rt]")
    throw err(400, "WebSocket upgrade not available")
  }

  ** Authenticate the request against the runtime
  private Bool authenticate()
  {
    cx = sys.user.authenticate(req, res, rt)
    if (cx == null) return false

    cx.timeout = rt.meta.evalTimeout
    return true
  }

  ** Check and validate the Xeto-Version header; v4 assumed if undefined
  private Void resolveVersion()
  {
    header := req.headers["Xeto-Version"]
    version = header == null ? 4 : header.toInt(10, false)
    if (version != 4 && version != 5)
      throw err(400, "Unsupported Xeto-Version: $header (supported: 4, 5)")
  }

  ** Map opName to its op function
  private Void resolveOpFunc()
  {
    // if path too short
    if (opName == null) throw err(404, "Invalid path")

    // rebase to to the op path "/api/{projName}/{opName}/..."
    req.modBase = req.uri[0..2].plusSlash

    // lookup all functions by name
    func = doResolveOpFunc(opName)
  }

  ** Lookup opName and check for ambiguous matches
  private Spec doResolveOpFunc(Str opName)
  {
    funcs := cx.ns.funcs.getAll(opName)
    if (funcs.size == 1) return funcs.first
    if (funcs.size == 0) throw err(404, "Unknown op: $opName")
    funcs = funcs.findAll |f| { f.meta.has("op") } // narrow down to <op> only
    if (funcs.size == 1) return funcs.first
    throw err(404, "Ambiguous ops: $funcs")
  }

//////////////////////////////////////////////////////////////////////////
// Dispatch
//////////////////////////////////////////////////////////////////////////

  ** Dispatch to the op function
  private Void dispatch()
  {
    // if func is <opWeb> its a direct dispatch
    if (func.meta.has("opWeb")) return call(Obj#.emptyList)

    // build dispatcher for this version and op
    dispatch := resolveDispatch

    // read the request to func args
    args := dispatch.readReq

    // invoke the function
    result := dispatch.call(args)

    // write the response; call may have already written an error response
    if (!res.isCommitted) dispatch.writeRes(result)
  }

  ** Call the op function (permission check is done here)
  internal Obj? call(Str[]? args)
  {
    try
      return func.func.thunk.callList(args)
    catch (EvalErr e)
      throw e.cause ?: e
  }

  ** Resolve base dispatch class
  private ApiDispatch resolveDispatch()
  {
    // version 5
    if (version == 5) return ApiDispatchV5(this)

    // version 4 fallbacks
    type := ApiDispatchV4Op.specials[opName]
    if (type != null) return type.make([this])
    return ApiDispatchV4(this)
  }

//////////////////////////////////////////////////////////////////////////
// Error Handling
//////////////////////////////////////////////////////////////////////////

  ** Return ApiErr to throw and funnel back thru writeErr
  ApiErr err(Int code, Str msg, Err? err := null)
  {
    ApiErr(code, msg, err)
  }

  ** Choke point for all error handling
  Void writeErr(Int code, Str msg, Err? err := null)
  {
    // if already commited then no can do
    if (res.isCommitted) return

    // build json body
    body := Str:Obj[:] { ordered = true }
    body["spec"] = "sys.api::Err"
    body["dis"]  = msg
    if (err != null && !ext.settings.disableErrTrace)
      body["errTrace"] = err.traceToStr

    // send error response
    res.statusCode = code
    res.statusPhrase = msg
    res.headers["Content-Type"] = "application/json"
    res.headers["Xeto-Version"] = "5"
    JsonOutStream(res.out).writeJson(body)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const Sys sys       // make
  const ApiExt ext    // make
  const Str[] path    // make
  const Str? rtName   // make
  const Str? opName   // make
  WebReq req          // make
  WebRes res          // make
  Runtime? rt         // resolveRuntime
  Context? cx         // authenticate
  Int? version        // resolveVersion
  Spec? func          // resolveOpFunc
}

**************************************************************************
** ApiErr
**************************************************************************

const class ApiErr : Err
{
  new make(Int code, Str msg, Err? cause := null) : super(msg, cause)
  {
    this.code = code
  }

  const Int code
}

