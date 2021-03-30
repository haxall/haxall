//
// Copyright (c) 2017, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Feb 2017  Brian Frank  Creation
//

using web

**
** WebOpUtil implements the standard logic for reading requests and
** writing responses for Haystack ops using HTTP content negotiation.
**
@NoDoc const mixin WebOpUtil
{

//////////////////////////////////////////////////////////////////////////
// Overrides
//////////////////////////////////////////////////////////////////////////

  ** Namespace to use for filetypes
  abstract Namespace ns()

  ** Lookup filetype for the given mime type or null
  virtual Filetype? toFiletype(MimeType mime)
  {
    ns.filetype(mime.noParams.toStr, false)
  }

  ** Get reader/writer options
  virtual Dict ioOpts(Filetype filetype, MimeType mime)
  {
    filetype.ioOpts(ns, mime, Etc.emptyDict, Etc.emptyDict)
  }

//////////////////////////////////////////////////////////////////////////
// Request
//////////////////////////////////////////////////////////////////////////

  ** Read a Haystack request grid as GET query params or POST body.
  ** If there is any errors then send HTTP error code and return null
  Grid? doReadReq(WebReq req, WebRes res)
  {
    if (req.isGet) return doReadReqGet(req, res)
    if (req.isPost) return doReadReqPost(req, res)
    res.sendErr(501, "$req.method.upper")
    return null
  }

  private Grid? doReadReqGet(WebReq req, WebRes res)
  {
    tags := Str:Obj[:]
    req.uri.query.each |valStr, key|
    {
      Obj? val := null
      try
        val = ZincReader(valStr.in).readVal
      catch
        val = valStr
      tags[key] = val
    }
    return Etc.makeMapGrid(null, tags)
  }

  private Grid? doReadReqPost(WebReq req, WebRes res)
  {
    // find reader to use for MIME type
    mime := MimeType(req.headers["Content-Type"] ?: "", false)
    if (mime == null) { res.sendErr(415, "Content-Type not specified"); return null }
    filetype := toFiletype(mime)
    if (filetype == null) { res.sendErr(415, "Unsupported Content-Type: $mime"); return null }

    // read content is as string
    reqStr := req.in.readAllStr

    // try to parse
    Err? err := null
    try
    {
      return filetype.reader(reqStr.in, ioOpts(filetype, mime)).readGrid
    }
    catch (Err e)
    {
      err = e
    }

    echo("ERROR: Invalid $mime format for request:\n$err\n$reqStr")
    res.sendErr(400, "Cannot parse $mime request: $err")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Response
//////////////////////////////////////////////////////////////////////////

  ** Write a Haystack response grid using content negotiation.
  Void doWriteRes(WebReq req, WebRes res, Grid result)
  {
    // parse Accept header to find requested mime type
    mime := acceptMimeType(req)
    if (mime == null) return res.sendErr(406, "Invalid Accept header")

    // find GridWriter to use for mime type
    filetype := toFiletype(mime)
    if (filetype == null) return res.sendErr(406, "Unsupported Accept type: $mime")

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
    writer := filetype.writer(out, ioOpts(filetype, mime))
    writer.writeGrid(result)
    out.close
  }

  ** Does the request accept gzip
  static Bool acceptGzip(WebReq req)
  {
    (req.headers["Accept-Encoding"] ?: "").contains("gzip")
  }

  private MimeType? acceptMimeType(WebReq req)
  {
    // check for filetype in query string for easy testing
    queryFiletype := req.uri.query["filetype"] ?: req.uri.query["format"]
    if (queryFiletype != null) return ns.filetype(queryFiletype).mimeType

    // if not specified or anything accepted default to text/plain (Zinc)
    accept := req.headers["Accept"]
    if (accept == null || accept.contains("*/*")) return mimeZinc

    // parse first mime type
    toks := accept.split(',')
    mime := MimeType.fromStr(toks.first, false)
    if (mime == null) return null
    return mime
  }

  private static const MimeType mimeZinc := MimeType("text/zinc; charset=utf-8")
}