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
      writeErr(e)
    }
    catch (PermissionErr e)
    {
      writeErr(ApiErr.permissionErr(e.msg, e.cause))
    }
    catch (UnknownRecErr e)
    {
      writeErr(ApiErr.unknownEntityErr(e.msg, e.cause))
    }
    catch (TimeoutErr e)
    {
      writeErr(ApiErr.timeoutErr(e.msg, e.cause))
    }
    catch (Err e)
    {
      writeErr(ApiErr.internalErr("Internal error: $e.msg", e))
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
    if (rtName == null) throw ApiErr.invalidPathErr

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
    throw ApiErr.unknownProjErr(rtName)
  }

  ** Check for websocket upgrade before authentication (not implemented yet)
  private Void upgrade()
  {
    // check for upgrade to websocket
    if (req.headers["Upgrade"] != "websocket") return

    // not implemented yet
    ext.log.warn("onWebSocket upgrade [$rt]")
    throw ApiErr.notImplementedErrWebSocket
  }

  ** Authenticate the request against the runtime.  A failure here is
  ** reported by the auth layer which writes its own 401 challenge, so
  ** no `sys.api::AuthErr` body is produced on this path.
  private Bool authenticate()
  {
    cx = sys.user.authenticate(req, res, rt)
    if (cx == null) return false

    cx.timeout = rt.meta.evalTimeout
    return true
  }

  ** Check and validate the requested version; v4 assumed if undefined.
  ** The Xeto-Version header is the primary mechanism; the "xeto-version"
  ** query param is a debugging affordance so a v5 request can be made
  ** from a browser address bar or curl without setting headers, and it
  ** takes precedence when both are given.  Clients should send the header.
  private Void resolveVersion()
  {
    token := req.uri.query["xeto-version"] ?: req.headers["Xeto-Version"]
    if (token == null) { version = ApiVersion.def; return }
    version = ApiVersion.fromToken(token, false)
    if (version == null) throw ApiErr.unsupportedVersionErr(token)
  }

  ** Map opName to its op function
  private Void resolveOpFunc()
  {
    // if path too short
    if (opName == null) throw ApiErr.invalidPathErr

    // rebase to to the op path "/api/{projName}/{opName}/..."
    req.modBase = req.uri[0..2].plusSlash

    // lookup all functions by name
    func = doResolveOpFunc(opName)
  }

  ** Lookup opName and check for ambiguous matches
  private Spec doResolveOpFunc(Str opName)
  {
    // qname is axon style "sys.api::about" (without Funcs)
    colon := opName.index("::")
    if (colon != null)
    {
      lib := cx.ns.lib(opName[0..<colon], false)
      spec := lib?.funcs?.get(opName[colon+2..-1], false)
      if (spec == null) throw ApiErr.unknownFuncErr(opName)
      return spec
    }

    // unqualified resolution
    funcs := cx.ns.funcs.getAll(opName)
    if (funcs.size == 1) return funcs.first
    if (funcs.size == 0) throw ApiErr.unknownFuncErr(opName)
    funcs = funcs.findAll |f| { f.meta.has("op") } // narrow down to <op> only
    if (funcs.size == 1) return funcs.first
    throw ApiErr.ambiguousFuncErr(opName, funcs.map |f->Str| { f.func.qname })
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

  ** Call the op function (permission check is done here).  Axon wraps
  ** everything a func raises in an EvalErr, so unwrap it here to expose
  ** the underlying err type.  This is the only unwrap site: the catch
  ** sequence in service matches on specific types like UnknownRecErr,
  ** which would otherwise all be masked by the EvalErr wrapper.
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
    if (version === ApiVersion.v5) return ApiDispatchV5(this)

    // version 4 fallbacks
    type := ApiDispatchV4Op.specials[opName]
    if (type != null) return type.make([this])
    return ApiDispatchV4(this)
  }

//////////////////////////////////////////////////////////////////////////
// Error Handling
//////////////////////////////////////////////////////////////////////////

  ** Choke point for all error handling
  Void writeErr(ApiErr err) { err.writeRes(res) }

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
  ApiVersion? version // resolveVersion
  Spec? func          // resolveOpFunc
}

