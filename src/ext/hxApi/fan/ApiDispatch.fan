//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jul 2026  Brian Frank  Creation
//

using xeto
using haystack
using axon
using hx
using web

**
** ApiDispatch is base class for dispatching via different protocol versions
**
abstract class ApiDispatch
{
  new make(ApiPipeline p) { this.p = p }

//////////////////////////////////////////////////////////////////////////
// Read/Write Hooks
//////////////////////////////////////////////////////////////////////////

  ** Verify the request method is allowed for this op.  This is separate
  ** from `readReq` because it applies to every op, including those which
  ** decode the request themselves and so never call readReq.  The pipeline
  ** is the single caller; see `hxApi::ApiPipeline.dispatch`.
  Void checkMethod()
  {
    if (req.isGet)
    {
      if (func.meta.missing("noSideEffects"))
        throw ApiErr.methodNotAllowedErr(func.name)
      return
    }
    if (req.isPost) return
    throw ApiErr.notImplementedErrMethod(req.method)
  }

  ** Read the request to function args based on GET or POST; the method has
  ** already been validated by `checkMethod`
  Obj?[] readReq()
  {
    req.isGet ? readReqGet : readReqPost
  }

  ** Read the request to function args from path or query string
  abstract Obj?[] readReqGet()

  ** Read the request to function args from post body
  abstract Obj?[] readReqPost()

  ** File typed param which receives the post body itself, or null when
  ** the op takes JSON args.  A file param must be the op's only param
  ** since the body is consumed whole - there is no encoding for mixed
  ** file and JSON args.
  Spec? fileParam()
  {
    params := func.func.params
    file := params.find |p| { isFileParam(p) }
    if (file == null) return null
    if (params.size > 1) throw ApiErr(400, "InvalidArgsErr", "File param must be op's only param: $func.name")
    return file
  }

  ** Does the param's type walk up to the sys::File root
  private static Bool isFileParam(Spec p)
  {
    for (Spec? x := p.type; x != null; x = x.base)
      if (x.qname == "sys::File") return true
    return false
  }

  ** Is this a grid based op which receives its request grid whole?
  ** Declared by the '<opGrid>' marker; grids are the blessed shape for
  ** the batch and tabular ops such as commit, hisWrite, and the watches.
  Bool isReqGridOp()
  {
    func.meta.has("opGrid")
  }

  ** Request Content-Type or raise 415 if missing
  MimeType reqMime()
  {
    mime := MimeType(req.headers["Content-Type"] ?: "", false)
    if (mime == null) throw ApiErr.unsupportedMediaTypeErrMissing
    return mime
  }

  ** Read the POST body as a grid using the filetype for the given mime.
  ** Raise 415 for an unreadable type and 400 when the body cannot parse.
  Grid readReqGrid(MimeType mime)
  {
    filetype := Filetype.byMime(mime, false)
    if (filetype == null || (!filetype.hasReader && !isXetoFiletype(filetype)))
      throw ApiErr.unsupportedMediaTypeErrReader(mime.toStr)
    reqStr := req.in.readAllStr
    try
    {
      // the xeto family reads through the namespace codec and bridges
      // any value to the request grid; refs are data pointing at recs,
      // not xeto instances, so resolution is external
      if (isXetoFiletype(filetype))
        return Etc.toGrid(filetype.name == "xeto" ? cx.ns.io.readXeto(reqStr, externRefs) : cx.ns.io.readJeto(reqStr.in))
      return filetype.reader(reqStr.in, ioOpts(mime)).readGrid
    }
    catch (Err e)
      throw ApiErr.invalidArgsErr(mime.toStr, e)
  }

  ** Write the result as a grid using the filetype for the given mime.
  ** Raise 406 when no writer supports it.
  Void writeResGrid(Obj? result, MimeType mime)
  {
    // find writer for mime type: GridWriter backed or the xeto family
    filetype := Filetype.byMime(mime, false)
    if (filetype == null || (!filetype.hasWriter && !isXetoFiletype(filetype)))
      throw ApiErr.notAcceptableErrWriter(mime.toStr)

    // a func with no result encodes as the empty grid clients expect;
    // Etc.toGrid would otherwise make a single row with a null val col
    grid := result == null ? Etc.emptyGrid : Etc.toGrid(result)

    // accept-encoding
    gzip := acceptGzip(req)

    // standard headers
    res.statusCode = 200
    res.headers["Content-Type"] = mime.toStr
    res.headers["Cache-Control"] = "no-cache, no-store"
    if (gzip) res.headers["Content-Encoding"] = "gzip"

    // write result
    OutStream out := res.out
    if (gzip) out = Zip.gzipOutStream(out)
    if (isXetoFiletype(filetype))
    {
      if (filetype.name == "xeto") cx.ns.io.writeXeto(out, grid)
      else cx.ns.io.writeJeto(out, grid)
    }
    else filetype.writer(out, ioOpts(mime)).writeGrid(grid)
    out.close
  }

  ** Is the filetype the xeto family, which encodes any value through
  ** the namespace codec rather than a GridReader/GridWriter
  static Bool isXetoFiletype(Filetype? filetype)
  {
    filetype != null && (filetype.name == "xeto" || filetype.name == "jeto")
  }

  private static const Dict externRefs := Etc.dict1("externRefs", Marker.val)

  ** Is the mime type application/json, which each version binds to its
  ** own codec: the haystack codec in v4, the xeto codec in v5
  static Bool isJsonMime(MimeType mime)
  {
    mime.mediaType == "application" && mime.subType == "json"
  }

  ** Filetype reader/writer options; JSON v3 is only reachable via an
  ** explicit ";version=3" mime param
  static Dict ioOpts(MimeType mime)
  {
    mime.params["version"] == "3" ? Etc.dict1("v3", Marker.val) : Etc.dict0
  }

  ** Temp file the post body was spooled into for a file param, or null.
  ** The pipeline deletes it after dispatch, so the op func must consume
  ** the file before it returns.
  @NoDoc File? uploadFile

  ** Delete the spooled upload if any; failures are swallowed since a
  ** temp file leak must never mask the real response
  @NoDoc Void cleanup() { try { uploadFile?.delete } catch {} }

  ** Map named args onto the positional list the thunk expects.  The given
  ** function decodes one arg by param, or returns null if the request had
  ** no value for it, in which case the param's default applies.
  **
  ** The default comes from 'metaOwn' so that meta inherited from the param's
  ** type is not mistaken for one: sys::Ref declares 'val:"x"' as an example
  ** which must never be injected as a caller's missing id.  This is the same
  ** distinction `xetom::MFunc.signature` makes when it reports defaults.
  Obj?[] mapArgs(|Spec->Obj?| f)
  {
    func.func.params.map |p->Obj?|
    {
      val := f(p)
      if (val != null) return val
      def := p.metaOwn["val"]
      if (def != null) return def
      if (p.isMaybe) return null
      throw ApiErr.invalidArgsErrMissing(func.name, p.name)
    }
  }

  ** Invalid the operation function with given args and return result
  virtual Obj? call(Obj?[] args) { p.call(args) }

  ** Write the result to the response body.  A file result is served as a
  ** download regardless of protocol version; anything else is encoded by
  ** the version specific `writeResVal`.
  Void writeRes(Obj? result)
  {
    file := result as File
    if (file != null) return writeResFile(file)
    writeResVal(result)
  }

  ** Serve a file result as an attachment download.  FileWeblet handles the
  ** mime type from the file extension plus ETag, Last-Modified, 304, and
  ** gzip.  An in memory result can use `sys::Buf.toFile` to name itself.
  **
  ** Calls onGet rather than onService because the method has already been
  ** validated by `checkMethod`: an op which returns a file is a download
  ** whether it was reached by GET or POST, and onService would answer a
  ** POST with the 501 from Weblet's own onPost.  onGet reads no method
  ** itself - it is the file serving routine, not a method handler.
  virtual Void writeResFile(File file)
  {
    weblet := FileWeblet(file)
    weblet.extraResHeaders = ["Content-Disposition": "attachment; filename=$file.name.toCode"]
    weblet.onGet
  }

  ** Encode a non-file result to the response body
  abstract Void writeResVal(Obj? result)

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Query params that control the request itself rather than supply an op
  ** argument.  These use an "xeto-" prefix which mirrors the request header.
  ** The prefix is reserved: a xeto identifier cannot contain a dash, so a
  ** control param can never collide with an op's parameter name.
  static Bool isControlParam(Str name)
  {
    name.startsWith("xeto-")
  }

  ** Return the accept mime type or
  MimeType? acceptMimeType(WebReq req, MimeType defaultMime)
  {
    // check for filetype in query string for easy testing
    queryFiletype := req.uri.query["xeto-filetype"]
    if (queryFiletype != null) return Filetype.byName(queryFiletype).mimeType

    // if not specified or anything accepted return return default
    accept := req.headers["Accept"]
    if (accept == null || accept.contains("*/*")) return defaultMime

    // parse first mime type
    toks := accept.split(',')
    mime := MimeType.fromStr(toks.first, false)
    if (mime == null) return null
    return mime
  }

  ** Does the request accept gzip
  static Bool acceptGzip(WebReq req)
  {
    (req.headers["Accept-Encoding"] ?: "").contains("gzip")
  }

  static const MimeType mimeZinc := MimeType("text/zinc; charset=utf-8")

  static const MimeType jsonMime := MimeType("application/json")

//////////////////////////////////////////////////////////////////////////
// Pipeline Conveniences
//////////////////////////////////////////////////////////////////////////

  WebReq req() { p.req }

  WebRes res() { p.res }

  Context cx() { p.cx }

  Spec func() { p.func }

  ApiPipeline pipeline() { p }

  private ApiPipeline p
}

