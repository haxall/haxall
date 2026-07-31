//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jun 2021  Brian Frank  Creation
//

using concurrent
using web
using xeto
using haystack
using axon
using folio

**
** Base class for Haxall 3.x style HTTP API operation processing
**
@NoDoc
const abstract class HxApiOp : WebOpUtil
{
  ** Lookup the singleton op instance for the given type qname
  static HxApiOp find(Str typeName)
  {
    op := ((Str:HxApiOp)cache.val)[typeName]
    if (op != null) return op
    op = (HxApiOp)Type.find(typeName).make
    cache.val = ((Str:HxApiOp)cache.val).dup.set(typeName, op).toImmutable
    return op
  }

  private static const AtomicRef cache := AtomicRef(Str:HxApiOp[:].toImmutable)

  ** Programmatic name of the op such as "read"
  abstract Str name()

  ** Return if this operation can be called with GET method
  virtual Bool noSideEffects() { false }

  ** Process an HTTP service call to this op
  virtual Void onService(WebReq req, WebRes res, Context cx)
  {
    // parse request grid; if readReq returns null
    // then an error has already been returned
    reqGrid := readReq(req, res)
    if (reqGrid == null) return

    // subclass hook
    resGrid := onRequest(reqGrid, cx)

    // respond with resulting grid
    writeRes(req, res, resGrid)
  }

  ** Process parsed request.  Default implentation
  ** attempts to eval an Axon function of the same name.
  abstract Grid onRequest(Grid req, Context cx)

  ** Read the request grid; GET is only allowed for ops with no side effects
  Grid? readReq(WebReq req, WebRes res)
  {
    if (req.isGet && !noSideEffects)
    {
      res.sendErr(405, "GET not allowed for op '$name'")
      return null
    }
    return doReadReq(req, res)
  }

  ** Write the response grid using content negotiation
  Void writeRes(WebReq req, WebRes res, Obj? result)
  {
    if (res.isCommitted) return
    doWriteRes(req, res, Etc.toGrid(result))
  }

  ** Convert exception to error response grid.  The api ext may
  ** disable the stack trace via its "disableErrTrace" setting.
  Grid toErrGrid(Context cx, Err err, Obj? meta := null)
  {
    if (cx.ext("hx.api", false)?.settings?.has("disableErrTrace") == true)
    {
      meta = Etc.makeDict(meta)
      meta = Etc.dictSet(meta, "errTrace", "${err}\n  Trace disabled")
    }
    return Etc.makeErrGrid(err, meta)
  }
}

**************************************************************************
** HxFuncOp
**************************************************************************

**
** Implements a legacy 3.x op by dispatching to a Xeto function.  This is
** the bridge which lets the v4 HTTP API keep its wire contract while the
** implementation lives in sys.api/ph.api as ordinary functions.
**
@NoDoc
const class HxFuncOp : HxApiOp
{
  ** Resolve an op name to the func which implements it, or null if no
  ** func is found.  A name may be defined by more than one lib: the HTTP
  ** API always binds to the func marked '<op>' which provides the wire
  ** semantics, while Axon binds to the unmarked function.  This is how
  ** 'sys.api::commit' and 'hx::commit' coexist under one name.
  static HxFuncOp? findByOpName(Str opName, Context cx)
  {
    matches := cx.ns.funcs.getAll(opName)
    if (matches.isEmpty) return null

    // prefer the op marked func, otherwise the sole definition
    func := matches.find |x| { x.meta.has("op") }
    if (func == null)
    {
      if (matches.size > 1) throw AmbiguousSpecErr(matches.toStr)
      func = matches.first
    }
    return HxFuncOp(opName, func)
  }

  ** Constructor
  private new make(Str name, Spec func)
  {
    this.name = name
    this.func = func
  }

  ** Legacy op name such as "hisRead"
  override const Str name

  ** Func spec which implements this op
  const Spec func

  ** GET is allowed if the func declares noSideEffects
  override Bool noSideEffects() { func.meta.has("noSideEffects") }

  ** An opWeb func reads the request and writes the response itself, so
  ** it is called with no args and nothing is encoded around it.  A
  ** permission failure is reported as a real status code: there is no
  ** result grid to carry the legacy 200 err grid.
  override Void onService(WebReq req, WebRes res, Context cx)
  {
    if (func.meta.missing("opWeb")) return super.onService(req, res, cx)
    try
      call(cx, Obj?[,])
    catch (PermissionErr e)
      if (!res.isCommitted) res.sendErr(403, "Forbidden")
  }

  override Grid onRequest(Grid req, Context cx)
  {
    // pass the request grid as the first arg and pad the rest with null,
    // same convention as the legacy func shim
    args := Obj?[req]
    for (i := 1; i<func.func.params.size; ++i) args.add(null)

    return Etc.toGrid(call(cx, args), req.meta)
  }

  ** Invoke the func, checking its declared permissions first.  The
  ** thunk is called directly rather than through the axon evaluator, so
  ** the su/admin markers must be enforced here; see `Context.checkCall`.
  private Obj? call(Context cx, Obj?[] args)
  {
    fn := func.func.thunk as Fn
    if (fn != null) cx.checkCall(fn)

    // unwrap EvalErr so the client sees the original error, matching
    // the legacy ops which called their implementation directly
    try
      return func.func.thunk.callList(args)
    catch (EvalErr e)
      throw e.cause ?: e
  }
}

**************************************************************************
** HxReadOp
**************************************************************************

**
** The v4 "read" op takes a request grid of filter or ids.  It is not
** modeled as a function because the v5 API provides the same capability
** with better ergonomics via `sys.api::Funcs.read`, `readById`,
** `readByIds`, and `readAll`.
**
internal const class HxReadOp : HxApiOp
{
  override Str name() { "read" }

  override Bool noSideEffects() { true }

  override Grid onRequest(Grid req, Context cx)
  {
    if (req.isEmpty) throw Err("Request grid is empty")

    if (req.has("filter"))
    {
      reqRow := req.first
      filter := Filter.fromStr(reqRow->filter)
      opts   := reqRow
      return cx.db.readAll(filter, opts)
    }

    if (req.has("id"))
    {
      return cx.db.readByIds(req.ids, false)
    }

    throw Err("Request grid missing id or filter col")
  }
}

**************************************************************************
** HxDefsOp
**************************************************************************

internal const class HxDefsOp : HxApiOp
{
  override Str name() { "defs" }

  override Bool noSideEffects() { true }

  override Grid onRequest(Grid req, Context cx)
  {
    opts := req.first as Dict ?: Etc.dict0
    limit := (opts["limit"] as Number)?.toInt ?: Int.maxVal
    filter := Filter.fromStr(opts["filter"] as Str ?: "", false)
    acc := Def[,]
    incomplete := false
    eachDef(cx) |def|
    {
      if (filter != null && !filter.matches(def, cx)) return
      if (acc.size >= limit) { incomplete = true; return }
      acc.add(def)
    }
    meta := incomplete ? Etc.dict2("incomplete", Marker.val, "limit", Number(limit)) : Etc.dict0
    return Etc.makeDictsGrid(meta, acc)
  }

  virtual Void eachDef(Context cx, |Def| f) { cx.defs.eachDef(f) }
}

**************************************************************************
** HxFiletypesOp
**************************************************************************

internal const class HxFiletypesOp : HxDefsOp
{
  override Str name() { "filetypes" }

  override Bool noSideEffects() { true }

  override Void eachDef(Context cx, |Def| f) { cx.defs.feature("filetype").eachDef(f) }
}

**************************************************************************
** HxLibsOp
**************************************************************************

internal const class HxLibsOp : HxDefsOp
{
  override Str name() { "libs" }

  override Bool noSideEffects() { true }

  override Void eachDef(Context cx, |Def| f) { cx.defs.libsList.each(f) }
}

**************************************************************************
** HxOpsOp
**************************************************************************

internal const class HxOpsOp : HxDefsOp
{
  override Str name() { "ops" }

  override Bool noSideEffects() { true }

  override Void eachDef(Context cx, |Def| f) { cx.defs.feature("op").eachDef(f) }
}

