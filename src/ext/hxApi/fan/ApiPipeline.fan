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
      if (routeRemote) return
      resolveRuntime
      if (upgrade) return
      if (!authenticate) return
      resolveVersion
      if (onAuthenticated) return
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
    catch (UnknownWatchErr e)
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

  ** Check if the rtName routes this request to a remote node.  Return
  ** true if  processed or false to continue the standard pipeline.
  protected virtual Bool routeRemote() { false }

  ** Resolve /api/{rt name} to the runtime
  private Void resolveRuntime()
  {
    // short circuit if rt already resolved
    if (rt != null) return

    // verify path as "/api/{rtName}"
    if (rtName == null) throw ApiErr.invalidPathErr

    // "sys" is the reserved name for the system runtime itself
    if (rtName == "sys") { rt = sys; return }

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

  ** Check for a websocket upgrade before authentication.  An extension
  ** declares the protocols it services via `hx::ExtWeb.webSocketProtocols`
  ** and takes over the request entirely, including authenticating it.
  ** Returns true if the request was serviced as an upgrade.
  private Bool upgrade()
  {
    // check for websocket protocol header
    protocol := req.headers["Sec-WebSocket-Protocol"]
    if (protocol == null) return false

    // only a project can host a websocket endpoint
    if (!rt.isProj) return false

    // protocols are indexed at registry build time so this stays a hash
    // lookup on the request hot path
    web := rt.exts.webSocketRoutes[protocol]
    if (web == null) return false

    // dispatch; the ext services the whole request from here
    req.modBase = req.uri[0..1].plusSlash
    web.onWebSocket
    return true
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

  ** Hook called once the request is authenticated and the context is
  ** installed, but before the request body is read or any response is
  ** written.  Return true if the hook fully serviced the request, in
  ** which case the pipeline stops.
  **
  ** This is the seam for host level concerns which need the authenticated
  ** `hx::Context` and its session: tunnelling the raw request to another
  ** cluster node, or binding a UI session onto the context.  It must fire
  ** before the body is read because a subclass may pipe the unread body
  ** straight to another host.
  protected virtual Bool onAuthenticated() { false }

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

    // determine if function handles it own request and/or responses
    funcOwnsReq = ApiUtil.isOpWebReq(func)
    funcOwnsRes = ApiUtil.isOpWebRes(func)
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

  ** Dispatch to the op function.  A raw web func services part or all of
  ** the request itself: '<opWebReq>' reads the web request and owns the
  ** method rules, '<opWebRes>' writes the web response.
  **
  ** Note a func returning a file is not opWebRes: it returns the file
  ** and `ApiDispatch.writeResFile` serves it as a download.
  private Void dispatch()
  {
    // build dispatcher for this version and op; always, so that even a func
    // servicing its own request is doing it for the negotiated version
    dispatch := resolveDispatch

    // a func which decodes the request also interprets the method: hx.api::file
    // downloads on GET and uploads on POST/PUT, which no single marker models
    if (!funcOwnsReq) dispatch.checkMethod

    try
    {
      // read the request to func args
      args := funcOwnsReq ? Obj#.emptyList : dispatch.readReq

      // invoke the function
      result := dispatch.call(args)

      // write the response; call may have already written an error response
      if (!funcOwnsRes && !res.isCommitted) dispatch.writeRes(result)
    }
    finally dispatch.cleanup  // delete spooled upload if any
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

//////////////////////////////////////////////////////////////////////////
// Error Handling
//////////////////////////////////////////////////////////////////////////

  ** Choke point for all error handling
  Void writeErr(ApiErr err) { err.writeRes(res) }

  ** Write an err as a version 4 style 200 response carrying an error grid.
  ** This is the legacy wire contract: `haystack::Client` parses the grid to
  ** raise CallErr, so a real status code would surface as IOErr instead.
  ** The meta tags let the server hand recovery information back with the
  ** error, such as a replacement session key.
  @NoDoc Void writeErrGrid(Err err, [Str:Obj?]? meta := null)
  {
    acc := meta == null ? Str:Obj?[:] : meta.dup
    if (ext.settings.disableErrTrace)
      acc["errTrace"] = "${err}\n  Trace disabled"
    ApiDispatchV4(this).writeRes(Etc.makeErrGrid(err, Etc.makeDict(acc)))
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const Sys sys             // make
  const ApiExt ext          // make
  const Str[] path          // make
  const Str? rtName         // make
  const Str? opName         // make
  WebReq req                // make
  WebRes res                // make
  Runtime? rt               // resolveRuntime
  Context? cx               // authenticate
  ApiVersion? version       // resolveVersion
  Spec? func                // resolveOpFunc
  Bool funcOwnsReq          // resolveOpFunc
  Bool funcOwnsRes          // resolveOpFunc
}

