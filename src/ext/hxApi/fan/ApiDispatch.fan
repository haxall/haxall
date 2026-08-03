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
      if (p.type.isMaybe) return null
      throw ApiErr.invalidArgsErrMissing(func.name, p.name)
    }
  }

  ** Does this func take the whole request as a single opaque envelope?
  ** By convention such a param is named "req": it is a version 4 shaped op
  ** which has not been modeled with real params yet, so the request grid is
  ** passed through rather than mapped onto params.  The name is the contract
  ** rather than the type because these declare 'Grid', 'Obj', and 'Dict'
  ** interchangeably; a func with real params never calls one "req".
  virtual Bool funcTakesReqGrid()
  {
    params := func.func.params
    return params.size == 1 && params.first.name == "req"
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
  virtual Void writeResFile(File file)
  {
    weblet := FileWeblet(file)
    weblet.extraResHeaders = ["Content-Disposition": "attachment; filename=$file.name.toCode"]
    weblet.onService
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

