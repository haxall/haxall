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

  ** Read the request to function args based on GET or POST
  Obj?[] readReq()
  {
    if (req.isGet)
    {
      if (func.meta.missing("noSideEffects"))
        throw ApiErr.methodNotAllowedErr(func.name)
      return readReqGet
    }

    if (req.isPost)
    {
      return readReqPost
    }
    throw ApiErr.notImplementedErrMethod(req.method)
  }

  ** Read the request to function args from path or query string
  abstract Obj?[] readReqGet()

  ** Read the request to function args from post body
  abstract Obj?[] readReqPost()

  ** Invalid the operation function with given args and return result
  virtual Obj? call(Obj?[] args) { p.call(args) }

  ** Write the request to the response body
  abstract Void writeRes(Obj? result)

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Return the accept mime type or
  MimeType? acceptMimeType(WebReq req, MimeType defaultMime)
  {
    // check for filetype in query string for easy testing
    queryFiletype := req.uri.query["filetype"] ?: req.uri.query["format"]
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

  ApiExt ext() { p.ext }

  WebReq req() { p.req }

  WebRes res() { p.res }

  Context cx() { p.cx }

  Str opName() { p.opName }

  Spec func() { p.func }

  private ApiPipeline p
}

