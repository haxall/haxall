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

  ** Protocol version this dispatcher implements
  abstract ApiVersion version()

//////////////////////////////////////////////////////////////////////////
// Read Request
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

  ** Read the POST body as a grid using the resolved filetype.
  ** Raise 400 when the body cannot parse.
  Grid readReqGrid(Filetype filetype)
  {
    try
      return Etc.toGrid(filetype.apiDecode(cx.ns, req.in))
    catch (Err e)
      throw ApiErr.invalidArgsErr(filetype.name, e)
  }

  ** Temp file the post body was spooled into for a file param, or null.
  ** The pipeline deletes it after dispatch, so the op func must consume
  ** the file before it returns.
  internal File? uploadFile

  ** Delete the spooled upload if any; failures are swallowed since a
  ** temp file leak must never mask the real response
  internal Void cleanup() { try { uploadFile?.delete } catch {} }

//////////////////////////////////////////////////////////////////////////
// Call
//////////////////////////////////////////////////////////////////////////

  ** Invoke the operation function with given args and return result
  virtual Obj? call(Obj?[] args) { p.call(args) }

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

  ** Map a request grid onto the function args.  When 'whole' the grid
  ** itself is the single argument; otherwise the first row's cells are
  ** the named args.  A cell which matches no param is ignored rather
  ** than rejected - clients may send extra columns; a param with no
  ** cell falls back to its default.  Note only the first row is read:
  ** an op which needs the other rows must take the grid whole.
  Obj?[] mapGridArgs(Grid grid, Bool whole)
  {
    if (whole) return Obj?[grid]
    row := grid.first
    return mapArgs |p->Obj?| { row?.get(p.name) }
  }

//////////////////////////////////////////////////////////////////////////
// Write Response
//////////////////////////////////////////////////////////////////////////

  ** Write the result enveloped as a grid, which is how both protocol
  ** versions answer the grid based filetypes
  Void writeResGrid(Filetype filetype, Obj? result)
  {
    writeResBody(filetype, result == null ? Etc.emptyGrid : Etc.toGrid(result))
  }

  ** Write the response body: status code, headers, and gzip plumbing
  ** around the filetype encoder
  Void writeResBody(Filetype filetype, Obj? val)
  {
    gzip := acceptGzip

    // standard headers
    res.statusCode = 200
    res.headers["Content-Type"] = filetype.mimeRes.toStr
    res.headers["Cache-Control"] = "no-cache, no-store"
    if (gzip) res.headers["Content-Encoding"] = "gzip"

    // write result
    OutStream out := res.out
    if (gzip) out = Zip.gzipOutStream(out)
    filetype.apiEncode(cx.ns, out, val)
    out.close
  }

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

  ** Resolve the request Content-Type filetype or raise 415 ApiErr
  Filetype reqFiletype()
  {
    mime := reqMime
    filetype := Filetype.apiMime(mime, version)
    if (filetype == null || !filetype.canRead) throw ApiErr.unsupportedMediaTypeErrReader(mime.toStr)
    return filetype
  }

  ** Request Content-Type or raise 415 ApiErr if missing
  private MimeType reqMime()
  {
    mime := MimeType(req.headers["Content-Type"] ?: "", false)
    if (mime == null) throw ApiErr.unsupportedMediaTypeErrMissing
    return mime
  }

  ** Resolve the Accept header filetype or raise 406 ApiErr
  Filetype acceptFiletype()
  {
    mime := acceptMimeType
    filetype := Filetype.apiMime(mime, version)
    if (filetype == null || !filetype.canWrite) throw ApiErr.notAcceptableErrWriter(mime?.toStr ?: "")
    return filetype
  }

  ** Return the Accept mime type, or null when no preference is
  ** given so that `Filetype.apiMime` supplies the version default.
  ** Raise 406 ApiErr for invalid accepts.
  private MimeType? acceptMimeType()
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
  Bool acceptGzip()
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

