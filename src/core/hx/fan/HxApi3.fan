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

  override Grid onRequest(Grid req, Context cx)
  {
    // pass the request grid as the first arg and pad the rest with null,
    // same convention as the legacy func shim
    args := Obj?[req]
    for (i := 1; i<func.func.params.size; ++i) args.add(null)

    // unwrap EvalErr so the client sees the original error, matching
    // the legacy ops which called their implementation directly
    try
      return Etc.toGrid(func.func.thunk.callList(args), req.meta)
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

**************************************************************************
** HxExtOp
**************************************************************************

internal const class HxExtOp : HxApiOp
{
  override Str name() { "ext" }

  override Void onService(WebReq req, WebRes res, Context cx)
  {
    // TODO: rel paths not working great

    // by the time the op is called the modBase is `/api/{proj}/ext/` which means
    // the route name is the first element of modRel
    routeName := req.modRel.path.getSafe(0) ?: ""
    modBase := `/api/${cx.rt.name}/ext/${routeName}/`
    mod := cx.rt.exts.webRoutes.get(routeName)
    if (mod == null) return res.sendErr(404)

    // dispatch to web mod
    req.mod = mod
    req.modBase = modBase
    mod.onService
  }

  override Grid onRequest(Grid req, Context cx) { throw UnsupportedErr() }
}

**************************************************************************
** HxFileOp
**************************************************************************

internal const class HxFileOp : HxApiOp
{
  override Str name() { "file" }

  override Bool noSideEffects() { true }

  override Grid onRequest(Grid req, Context cx) { throw UnsupportedErr() }

  override Void onService(WebReq req, WebRes res, Context cx)
  {
    // {api file}/{path} => /{path}
    path := `/` + req.modRel
// cx.proj.log.info(">>> $req.modRel.toCode => $path.toCode")

    // we need to allow directories for rec/ upload and other exts might want
    // to support that also, so we won't enforce this check right now
    // if (path.isDir) return res.sendErr(400, "Not a file: $req.uri")

    // check for proj-relative path
    fileExt  := cx.sys.file
    subMount := path.path.first
    if (!cx.sys.isProj && subMount != "proj")
    {
      try
      {
        if (fileExt.resolve(`/proj/${cx.rt.name}/${subMount}/`).exists)
          path = `/proj/${cx.rt.name}${path}`
      }
      catch (Err ignore) { }
    }

    switch (req.method)
    {
      case "GET":
        onFileDownload(req, res, cx, path)
      case "POST":
      case "PUT":
        // fall-through
        onFileUpload(req, res, cx, path)
      default:
        res.sendErr(404)
    }
  }

  ** note that download is only supported for the file ext
  private Void onFileDownload(WebReq req, WebRes res, Context cx, Uri path)
  {
    if (path.isDir) return res.sendErr(404)
    file := cx.sys.file.resolve(path)
    FileWeblet(file).onService
  }

  private Void onFileUpload(WebReq req, WebRes res, Context cx, Uri path)
  {
    Ext ext := cx.sys.file

    // handle ext delegation /uploads/<xeto lib>/<path>
    names := path.path
    if (names.first == "uploads")
    {
      ext  = cx.proj.ext(names[1])
      path = path.getRangeToPathAbs(2..-1)
    }

    try
    {
      opts := Etc.dict1("path", path)
      ret  := cx.asCur { ext.uploadHandler(req, res, opts).upload }
      writeRes(req, res, ret)
    }
    catch (Err err)
    {
      err = Err("Upload failed by ${cx.user} for ${req.uri} (${path})", err)
      ext.log.err(err.msg, err)
      throw err
    }
  }
}

