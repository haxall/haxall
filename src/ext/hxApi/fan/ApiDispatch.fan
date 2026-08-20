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
      if (!ApiUtil.allowGet(func))
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

  ** Request Content-Type or raise 415 if missing
  MimeType reqMime()
  {
    mime := MimeType(req.headers["Content-Type"] ?: "", false)
    if (mime == null) throw ApiErr.unsupportedMediaTypeErrMissing
    return mime
  }

  ** Read the POST body as a grid using the resolved filetype.
  ** Raise 400 when the body cannot parse.
  Grid readReqGrid(Filetype filetype)
  {
    try
      return Etc.toGrid(filetype.apiDecode(cx.ns, req.in))
    catch (Err e)
      throw ApiErr.invalidArgsErr(filetype.name, e)
  }

  ** Write the result as a grid using the resolved filetype
  Void writeResGrid(Obj? result, Filetype filetype)
  {
    // both protocol versions envelope filetype responses as a grid
    grid := result == null ? Etc.emptyGrid : Etc.toGrid(result)

    // accept-encoding
    gzip := acceptGzip(req)

    // standard headers
    res.statusCode = 200
    res.headers["Content-Type"] = filetype.mimeRes.toStr
    res.headers["Cache-Control"] = "no-cache, no-store"
    if (gzip) res.headers["Content-Encoding"] = "gzip"

    // write result
    OutStream out := res.out
    if (gzip) out = Zip.gzipOutStream(out)
    filetype.apiEncode(cx.ns, out, grid)
    out.close
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
      // a file typed param takes the raw body, never an encoded arg
      if (p.type.isFile) throw ApiErr(400, "InvalidArgsErr", "File param must be op's only param: $func.name")
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

  ** Return the Accept mime type, or null when no preference is given
  ** so that `Filetype.apiMime` supplies the version default
  MimeType? acceptMimeType(WebReq req)
  {
    // check for filetype in query string for easy testing
    queryFiletype := req.uri.query["xeto-filetype"]
    if (queryFiletype != null)
    {
      f := Filetype.byName(queryFiletype, false) ?: throw ApiErr.notAcceptableErrWriter(queryFiletype)
      return f.mime
    }

    // no preference
    accept := req.headers["Accept"]
    if (accept == null || accept.contains("*/*")) return null

    // parse first mime type; an unparseable header is a 406
    mime := MimeType.fromStr(accept.split(',').first, false)
    if (mime == null) throw ApiErr.notAcceptableErrHeader
    return mime
  }

  ** Does the request accept gzip
  static Bool acceptGzip(WebReq req)
  {
    (req.headers["Accept-Encoding"] ?: "").contains("gzip")
  }

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

